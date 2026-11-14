# SPINFORGE web build (first playable)

Godot 4.7.2 Web export (single-threaded, PWA) of `src/ui/app.tscn`, built with:

    godot --headless --path . --export-release "Web" build/web/index.html
    cp build/web/* web/

This folder is what Vercel serves (project root directory `web/`, no build step).
It is generated output: never edit these files by hand; re-export instead.
