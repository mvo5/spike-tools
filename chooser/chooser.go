package main

import (
	"bufio"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path"
	"time"

	nc "github.com/gbin/goncurses"
)

var name string

func main() {

	title := flag.String("title", "Choose the recovery version", "Menu title")
	timeout := flag.Int("timeout", 5, "Timeout in seconds")
	flag.Parse()

	mntSysRecover := "/mnt/sys-recover"
	if err := os.MkdirAll(mntSysRecover, 0755); err != nil {
		log.Fatal("cannot create mountpointr: %s", err)
	}
	// FIXME: determine recovery from label
	if err := mount("/dev/sda2", mntSysRecover); err != nil {
		log.Fatal("cannot mount recovery: %s", err)
	}

	versions, err := getRecoveryVersions(mntSysRecover)
	if err != nil {
		log.Fatal("cannot get recovery versions: %s", err)
	}

	if err := umount(mntSysRecover); err != nil {
		log.Fatal("cannot unmount recovery: %s", err)
	}

	version, err := getSelection(*title, *timeout, versions)
	if err != nil {
		log.Fatal("cannot get selected version: %s", err)
	}

	// spike shortcut: we should now start the recovery task passing version
	//                 instead of creating a temp file
	f, err := os.Create("/tmp/recovery-version")
	if err != nil {
		log.Fatal("cannot create version file: %s", err)
	}
	defer f.Close()
	w := bufio.NewWriter(f)
	w.WriteString(version)
	w.Flush()
}

func getSelection(title string, timeout int, versions []string) (string, error) {
	scr, err := nc.Init()
	if err != nil {
		log.Fatal(err)
	}
	defer nc.End()

	nc.Raw(true)
	nc.Echo(false)
	nc.Cursor(0)
	scr.Clear()
	scr.Keypad(true)

	scr.Println(title)

	items := make([]*nc.MenuItem, len(versions))
	for i, val := range versions {
		items[i], _ = nc.NewItem(val, "")
		defer items[i].Free()
	}

	menu, err := nc.NewMenu(items)
	if err != nil {
		return "", err
	}
	defer menu.Free()

	win, err := nc.NewWindow(10, 40, 2, 0)
	if err != nil {
		return "", err
	}
	win.Keypad(true)

	menu.SetWindow(win)
	menu.SubWindow(win.Derived(5, 36, 1, 3))
	menu.Mark("> ")

	scr.Refresh()

	menu.Post()
	defer menu.UnPost()
	win.Refresh()

	countch := make(chan int)
	keych := make(chan nc.Key)

	go countdown(countch, timeout)
	go readkey(keych, win)

	for {
		select {
		case ch := <-keych:
			nc.Update()

			switch nc.KeyString(ch) {
			case "enter":
				return menu.Current(nil).Name(), nil
			case "down":
				menu.Driver(nc.REQ_DOWN)
			case "up":
				menu.Driver(nc.REQ_UP)
			}
			win.Refresh()
		case t := <-countch:
			win.MovePrint(8, 0, fmt.Sprintf("Time to select: %2d ", t))
			win.Refresh()
			if t == 0 {
				return menu.Current(nil).Name(), nil
			}
		}
	}
}

func readkey(keych chan nc.Key, win *nc.Window) {
	for {
		keych <- win.GetChar()
	}
}

func countdown(countch chan int, val int) {
	for val >= 0 {
		countch <- val
		val--
		time.Sleep(1 * time.Second)
	}
}

func getRecoveryVersions(mnt string) ([]string, error) {
	files, err := ioutil.ReadDir(path.Join(mnt, "system"))
	if err != nil {
		return []string{}, fmt.Errorf("cannot read recovery list: %s", err)
	}
	list := make([]string, len(files))
	for i, f := range files {
		list[i] = f.Name()
	}
	return list, nil
}

func mount(dev, mountpoint string) error {
	if err := exec.Command("mount", dev, mountpoint).Run(); err != nil {
		return fmt.Errorf("cannot mount device %s: %s", dev, err)
	}

	return nil
}

func umount(dev string) error {
	if err := exec.Command("umount", dev).Run(); err != nil {
		return fmt.Errorf("cannot unmount device %s: %s", dev, err)
	}

	return nil
}
