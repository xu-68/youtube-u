"""Compile the actual marker renderer with UIKit fixtures, not a second implementation."""
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
plugin = root / 'Tweaks/iSponsorBlock'
original = subprocess.check_output(['git', '-C', str(plugin), 'show', 'HEAD:iSponsorBlock.xm'], text=True)
patched = (plugin / 'iSponsorBlock.xm').read_text()

def renderer(source, name):
    start = source.index('static void setSkipSegments(YTModularPlayerBarView *self,')
    end = source.index('\nstatic void updateSkipSegments(', start)
    return source[start:end].replace('setSkipSegments(', name + '(', 1).replace('%c(YTPlayerViewController)', '[YTPlayerViewController class]')

fixture = (root / 'tests/MarkerRegression.mm').read_text()
fixture = fixture.replace('// INSERT_ACTUAL_RENDERERS', renderer(original, 'baselineRenderer') + '\n' + renderer(patched, 'patchedRenderer'))
pathlib.Path(sys.argv[1]).write_text(fixture)
