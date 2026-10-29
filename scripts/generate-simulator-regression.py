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
overlay = root / 'Tweaks/YTVideoOverlay'
original_overlay = subprocess.check_output(['git', '-C', str(overlay), 'show', 'HEAD:Tweak.x'], text=True)
patched_overlay = (overlay / 'Tweak.x').read_text()
def controls(source, name):
    start = source.index('static NSMutableArray *topControls(')
    end = source.index('\nstatic void setDefaultTextStyle(', start)
    return source[start:end].replace('topControls(', name + '(', 1)
fixture = fixture.replace('// INSERT_ACTUAL_CONTROLS', controls(original_overlay, 'baselineTopControls') + '\n' + controls(patched_overlay, 'patchedTopControls'))
pathlib.Path(sys.argv[1]).write_text(fixture)
