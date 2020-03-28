package main

import (
	"errors"
	"log"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/ddddddO/tag-mng/tools/health-cheack/health-cheack/lib"
)

const (
	target   = "https://ddddddo.work"
	proxySrc = "http://www.gatherproxy.com/ja"
	filePath = "./tmp.txt"
)

func main() {
	log.Print("start health cheack")

	pxs, err := lib.FetchProxys(proxySrc, filePath)
	if err != nil {
		log.Print(err)
		os.Exit(0)
	}

	if err := cheackTarget(pxs, target); err != nil {
		log.Fatal(err)
	}

	log.Print("succeeded!")
}

func cheackTarget(pxs []*lib.Proxy, target string) error {
	pxsLength := len(pxs)
	rsltCh := make(chan bool, pxsLength)

	log.Print("max attack: ", pxsLength)

	for i, px := range pxs {
		go func(px *lib.Proxy, i int) {
			time.Sleep(time.Duration(i*2) * time.Second)

			proxy := px.IP + ":" + px.Port
			log.Print("proxy:", proxy)

			cmd := exec.Command("curl", "-v", "-k", target, "-x", proxy)
			outerr, err := cmd.CombinedOutput()
			if err != nil {
				rsltCh <- false
				return
			}

			dst := string(outerr)
			if strings.Contains(dst, "HTTP/1.1 200 OK") {
				rsltCh <- true
				return
			}

			rsltCh <- false
		}(px, i)
	}

	for i := 0; i < pxsLength; i++ {
		select {
		case rslt := <-rsltCh:
			if rslt {
				return nil
			}
		}
	}

	return errors.New("probably not accessible")
}