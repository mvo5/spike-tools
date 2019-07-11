package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path"
	"time"

	nc "github.com/gbin/goncurses"
)

var name string

func main() {

	title := flag.String("title", "Choose the recovery version", "Menu title")
	output := flag.String("output", "/run/chooser.out", "Output file location")
	seed := flag.String("seed", "/run/ubuntu-seed", "Ubuntu-seed location")
	timeout := flag.Int("timeout", 5, "Timeout in seconds")
	flag.Parse()

	versions, err := getRecoveryVersions(*seed)
	if err != nil {
		log.Fatalf("cannot get recovery versions: %s", err)
	}

	version, err := getSelection(*title, *timeout, versions)
	if err != nil {
		log.Fatalf("cannot get selected version: %s", err)
	}

	config := fmt.Sprintf("uc_recovery_system=%q", version)
	if err := ioutil.WriteFile(*output, []byte(config), 0644); err != nil {
		log.Fatalf("cannot write configuration file: %s", err)
		os.Exit(1)
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
	files, err := ioutil.ReadDir(path.Join(mnt, "systems"))
	if err != nil {
		return []string{}, fmt.Errorf("cannot read recovery list: %s", err)
	}
	list := make([]string, len(files))
	for i, f := range files {
		list[i] = f.Name()
	}
	return list, nil
}
