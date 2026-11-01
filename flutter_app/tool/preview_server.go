// A loopback-only static server for the exported Flutter web preview.
// The Windows launcher opens the user's browser; tests disable that explicitly.
package main

import (
	"errors"
	"flag"
	"fmt"
	"mime"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"time"
)

func run() error {
	executable, err := os.Executable()
	if err != nil {
		return err
	}
	defaultRoot := filepath.Join(filepath.Dir(executable), "..", "web")
	root := flag.String("root", defaultRoot, "Ordner mit dem gebauten Flutter-Webprojekt")
	port := flag.Int("port", 8081, "Lokaler Port; fuer denselben Datenstand unveraendert lassen")
	openBrowser := flag.Bool("open-browser", runtime.GOOS == "windows", "Standardbrowser unter Windows oeffnen")
	flag.Parse()
	if *port < 1 || *port > 65535 {
		return errors.New("Port muss zwischen 1 und 65535 liegen")
	}
	webRoot, err := filepath.Abs(*root)
	if err != nil {
		return err
	}
	for _, name := range []string{"index.html", "version.json", "main.dart.js", "drift_worker.js", "sqlite3.wasm"} {
		info, err := os.Stat(filepath.Join(webRoot, name))
		if err != nil || info.IsDir() {
			return fmt.Errorf("Webdatei %s fehlt. Bitte das gesamte ZIP entpacken", name)
		}
	}
	listener, err := net.Listen("tcp4", fmt.Sprintf("127.0.0.1:%d", *port))
	if err != nil {
		return fmt.Errorf("Vorschau auf Port %d konnte nicht starten: %w", *port, err)
	}
	defer listener.Close()
	_ = mime.AddExtensionType(".wasm", "application/wasm")
	_ = mime.AddExtensionType(".js", "application/javascript")
	files := http.FileServer(http.Dir(webRoot))
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cross-Origin-Opener-Policy", "same-origin")
		w.Header().Set("Cross-Origin-Embedder-Policy", "require-corp")
		w.Header().Set("Cache-Control", "no-store")
		files.ServeHTTP(w, r)
	})
	url := fmt.Sprintf("http://127.0.0.1:%d/", *port)
	fmt.Println("FLEX Flutter-Webvorschau")
	fmt.Println("Adresse:", url)
	fmt.Println("Dieses Fenster offen lassen. Beenden: Strg+C oder Fenster schliessen.")
	fmt.Println("Daten bleiben im jeweiligen Browserprofil an dieser Adresse gespeichert.")
	if *openBrowser && runtime.GOOS == "windows" {
		command := exec.Command("rundll32.exe", "url.dll,FileProtocolHandler", url)
		if err := command.Start(); err != nil {
			fmt.Println("Browser bitte selbst mit der oben angegebenen Adresse oeffnen:", err)
		} else {
			go func() { _ = command.Wait() }()
		}
	}
	server := &http.Server{
		Handler:           handler,
		ReadHeaderTimeout: 10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
	return server.Serve(listener)
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "FLEX-Vorschau:", err)
		os.Exit(1)
	}
}
