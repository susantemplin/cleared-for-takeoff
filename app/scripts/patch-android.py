#!/usr/bin/env python3
"""Applies Cleared for Takeoff's settings to the freshly generated Android project.
Run from the app folder after `npx cap add android` and `npx cap sync android`."""
import json, os, re, shutil, sys

APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AND = os.path.join(APP, 'android', 'app')
RES = os.path.join(AND, 'src', 'main', 'res')
MANIFEST = os.path.join(AND, 'src', 'main', 'AndroidManifest.xml')
GRADLE = os.path.join(AND, 'build.gradle')

def read(p): return open(p, encoding='utf-8').read()
def write(p, s): open(p, 'w', encoding='utf-8').write(s)

# 1. Icons, notification icon, splash
src = os.path.join(APP, 'resources', 'android', 'res')
for root, _, files in os.walk(src):
    for f in files:
        rel = os.path.relpath(os.path.join(root, f), src)
        dst = os.path.join(RES, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copyfile(os.path.join(root, f), dst)
for d in os.listdir(RES):  # one splash for every screen (drawable/splash.png, center-cropped)
    if d.startswith('drawable-') and os.path.exists(os.path.join(RES, d, 'splash.png')):
        os.remove(os.path.join(RES, d, 'splash.png'))
print('icons + splash copied')

# 2. Permissions: microphone (Tap to talk), notifications (reminders), speech service lookup
m = read(MANIFEST)
perms = ['android.permission.RECORD_AUDIO', 'android.permission.POST_NOTIFICATIONS']
add = ''.join('    <uses-permission android:name="%s" />\n' % p for p in perms if p not in m)
if '<queries>' not in m:
    add += ('    <queries>\n        <intent>\n            <action android:name="android.speech.RecognitionService" />\n'
            '        </intent>\n    </queries>\n')
if add:
    m = m.replace('<application', add + '\n    <application', 1)
# keep the app from reloading when the screen size or density changes (Capacitor 8 guide)
m = re.sub(r'android:configChanges="([^"]*)"', lambda x: x.group(0) if 'density' in x.group(1) else 'android:configChanges="%s|density"' % x.group(1), m)
write(MANIFEST, m)
print('manifest updated')

# 3. Version: name from package.json, code always higher than the last upload
pkg = json.load(open(os.path.join(APP, 'package.json')))
code = int(os.environ.get('VERSION_CODE', '100'))
g = read(GRADLE)
g, n1 = re.subn(r'versionCode\s*=?\s*\d+', 'versionCode = %d' % code, g)
g, n2 = re.subn(r'versionName\s*=?\s*"[^"]*"', 'versionName = "%s"' % pkg['version'], g)
if not (n1 and n2):
    sys.exit('Could not find versionCode/versionName in build.gradle')

# 4. Signing for Google Play (only when the upload key is provided as a secret),
#    and a separate ".test" app id for test builds so they install next to the store app.
if 'CFT_KEYSTORE' not in g:
    g += '''
android {
    signingConfigs {
        release {
            if (System.getenv("CFT_KEYSTORE")) {
                storeFile = file(System.getenv("CFT_KEYSTORE"))
                storePassword = System.getenv("CFT_STORE_PASSWORD")
                keyAlias = System.getenv("CFT_KEY_ALIAS")
                keyPassword = System.getenv("CFT_KEY_PASSWORD")
            }
        }
    }
    buildTypes {
        release {
            if (System.getenv("CFT_KEYSTORE")) {
                signingConfig = signingConfigs.release
            }
        }
        debug {
            applicationIdSuffix = ".test"
            versionNameSuffix = "-test"
        }
    }
}
'''
write(GRADLE, g)
print('build.gradle: versionCode %d, versionName %s' % (code, pkg['version']))

# 5. Android 12+ launch screen color
styles = os.path.join(RES, 'values', 'styles.xml')
if os.path.exists(styles):
    s = read(styles)
    if 'windowSplashScreenBackground' not in s:
        s = re.sub(r'(<style name="AppTheme.NoActionBarLaunch"[^>]*>)',
                   r'\1\n        <item name="windowSplashScreenBackground">#14304F</item>', s, count=1)
        write(styles, s)
print('done')
