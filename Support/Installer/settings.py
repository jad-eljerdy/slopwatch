from pathlib import Path
import subprocess

app = Path(defines["app"])
files = [str(app)]
symlinks = {"Applications": "/Applications"}
format = "UDZO"
icon = str(app / "Contents/Resources/Slopwatch.icns")
background = defines["background"]
window_rect = ((130, 110), (660, 420))
icon_size = 88
text_size = 13
icon_locations = {app.name: (160, 251), "Applications": (500, 251)}


def create_hook(mount_point, options):
    # Finder attributes on the copied app can invalidate its signature.
    subprocess.run(
        ["/usr/bin/codesign", "--verify", "--deep", "--strict", "--all-architectures",
         str(Path(mount_point) / app.name)],
        check=True,
    )
