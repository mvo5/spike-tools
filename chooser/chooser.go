package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path"
	"regexp"
	"time"

	nc "github.com/gbin/goncurses"
)

var name string

func main() {

	title := flag.String("title", "Choose the recovery version", "Menu title")
	install := flag.Bool("install", false, "Run mode")
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

	version, err := getSelection(*title, *timeout, versions)
	if err != nil {
		log.Fatal("cannot get selected version: %s", err)
	}

	if *install {
		if err := umount(mntSysRecover); err != nil {
			log.Fatal("cannot unmount recovery: %s", err)
		}

		// Install mode
		if err := exec.Command("snap", "recover", "--install", version).Run(); err != nil {
			log.Fatal("cannot run install command: %s", err)
		}
		return
	}

	// Recovery mode

	// See if we selected the same version we booted
	bootVersion := getKernelParameter("snap_recovery_system")
	if version == bootVersion {
		// same version, we're good to go
		if err := exec.Command("snap", "recover", version).Run(); err != nil {
			log.Fatal("cannot run recover command: %s", err)
		}
	} else {
		// different version, we need to reboot

		// update recovery mode
		env := NewEnv("/mnt/sys-recover/EFI/ubuntu/grubenv")
		if err := env.Load(); err != nil {
			log.Fatalf("cannot load recovery boot vars: %s", err)
		}

		// set version in grubenv
		env.Set("snap_recovery_system", version)

		// set mode to recover_reboot (no chooser)
		env.Set("snap_mode", "recover_reboot")

		if err := env.Save(); err != nil {
			log.Fatalf("cannot save recovery boot vars: %s", err)
		}

		if err := umount(mntSysRecover); err != nil {
			log.Fatal("cannot unmount recovery: %s", err)
		} else {
			// reboot (fast, we're on tmpfs)
			restart()
		}
	}
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

// From snapd/recovery/utils.go
func getKernelParameter(name string) string {
	f, err := os.Open("/proc/cmdline")
	if err != nil {
		return ""
	}
	defer f.Close()
	cmdline, err := ioutil.ReadAll(f)
	if err != nil {
		return ""
	}
	re := regexp.MustCompile(fmt.Sprintf(`\b%s=([A-Za-z0-9_-]*)\b`, name))
	match := re.FindSubmatch(cmdline)
	if len(match) < 2 {
		return ""
	}
	return string(match[1])
}

// From snapd/recovery/utils.go
func enableSysrq() error {
	f, err := os.Open("/proc/sys/kernel/sysrq")
	if err != nil {
		return err
	}
	defer f.Close()
	f.Write([]byte("1\n"))
	return nil
}

func restart() error {
	if err := enableSysrq(); err != nil {
		return err
	}

	f, err := os.OpenFile("/proc/sysrq-trigger", os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		return err
	}
	defer f.Close()
	f.Write([]byte("b\n"))

	// look away
	select {}
	return nil
}
