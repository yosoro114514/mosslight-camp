"""Recycle short-lived WebGL handles in Godot 4.4.1's single-threaded release export."""

from pathlib import Path
import sys
from tempfile import NamedTemporaryFile


# Emscripten #22425. Keep the original allocator for new names so they remain
# unique across tables. Only return a name to the table that released it.
ALLOCATOR = "getNewId:table=>{var ret=GL.counter++;"
RECYCLE = """releaseId: (table, id) => {
    if (table[id]) {
        table[id] = null;
        if (!table.freeIds) table.freeIds = [];
        table.freeIds.push(id);
    }
},
getNewId: table => {
    if (table.freeIds && table.freeIds.length) return table.freeIds.pop();
    var ret=GL.counter++;"""


def patch(runtime: Path) -> None:
    source = runtime.read_bytes()
    replacements = [(ALLOCATOR, RECYCLE)]
    for table in ("buffers", "vaos", "syncs", "framebuffers", "renderbuffers", "textures", "queries"):
        replacements.append((f"GL.{table}[id]=null", f"GL.releaseId(GL.{table},id)"))

    if all(new.encode() in source for _, new in replacements):
        return
    for old, new in replacements:
        if source.count(old.encode()) != 1:
            raise ValueError(f"Unexpected Web template in {runtime}: cannot locate {old!r} exactly once")
        source = source.replace(old.encode(), new.encode())

    with NamedTemporaryFile(dir=runtime.parent, delete=False) as output:
        output.write(source)
    temporary = Path(output.name)
    try:
        temporary.chmod(runtime.stat().st_mode)
        temporary.replace(runtime)
    finally:
        temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    patch(Path(sys.argv[1]))
