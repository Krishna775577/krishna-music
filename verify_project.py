from pathlib import Path
import re
R=Path(__file__).resolve().parent
root=(R/'android/build.gradle').read_text()
app=(R/'android/app/build.gradle').read_text()
pub=(R/'pubspec.yaml').read_text()
assert not re.search(r"(?m)^\s*apply\s+plugin:\s*['\"]com\.android\.application", root)
assert "classpath 'com.android.tools.build:gradle:7.4.2'" in root
assert "apply plugin: 'com.android.application'" in app
assert 'compileSdkVersion 34' in app
assert re.search(r'(?m)^\s*receive_sharing_intent:\s*1\.5\.4\s*$', pub)
assert re.search(r'(?m)^\s*youtube_player_iframe:\s*4\.0\.4\s*$', pub)
assert not (R/'lib/Screens/Settings/music_playback.dart').read_text().count('home_screen.fetched')
print('Static Android / Flutter compatibility checks passed.')
# Player routing regression checks: no external YouTube primary control.
nav=(R/'lib/Services/youtube_embed_navigation.dart').read_text()
player=(R/'lib/Screens/YouTube/official_youtube_player.dart').read_text()
search=(R/'lib/Screens/Search/search.dart').read_text()
assert 'OfficialYouTubePlayerPage(' in nav
assert 'initialIndex:' in nav and 'queue:' in nav
assert 'YoutubePlayerScaffold(' in player
assert 'Open in YouTube' not in player
assert 'Retry in Krishna Music' in player
assert 'queue: items' in search and 'queue: listItems' in search
print('In-app YouTube/YtMusic queue and player routing checks passed.')
