#!/usr/bin/env python3
"""Builds App/room.html (Pork's room for the app) from room-template.html and pork.js."""
from pathlib import Path

here = Path(__file__).resolve().parent
html = (here / "room-template.html").read_text()
pork = (here / "pork.js").read_text()
(here.parent / "App" / "room.html").write_text(html.replace("/*PORK_JS*/", pork))
print("wrote App/room.html")
