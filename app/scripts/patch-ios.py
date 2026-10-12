#!/usr/bin/env python3
"""Applies Cleared for Takeoff's settings to the freshly generated iPhone project.
Run from the app folder after `npx cap add ios` and `npx cap sync ios`."""
import json, os, plistlib, re, shutil, sys

APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IOS = os.path.join(APP, 'ios', 'App')
PLIST = os.path.join(IOS, 'App', 'Info.plist')
PBX = os.path.join(IOS, 'App.xcodeproj', 'project.pbxproj')
ASSETS = os.path.join(IOS, 'App', 'Assets.xcassets')
RES = os.path.join(APP, 'resources', 'ios')

# 1. Icon (one 1024 image, no transparency) and launch image
shutil.copyfile(os.path.join(RES, 'AppIcon-512@2x.png'), os.path.join(ASSETS, 'AppIcon.appiconset', 'AppIcon-512@2x.png'))
splash_dir = os.path.join(ASSETS, 'Splash.imageset')
for f in os.listdir(splash_dir):
    if f.endswith('.png'):
        shutil.copyfile(os.path.join(RES, 'splash-2732x2732.png'), os.path.join(splash_dir, f))
print('icon + splash copied')

# 2. Info.plist: permission messages, no export-compliance question, portrait only
with open(PLIST, 'rb') as fh:
    p = plistlib.load(fh)
p['CFBundleDisplayName'] = 'Takeoff'
p['NSMicrophoneUsageDescription'] = 'Takeoff uses the microphone when you tap Tap to talk, so you can practice your interview answers out loud.'
p['NSSpeechRecognitionUsageDescription'] = 'Takeoff turns what you say into text so you can get feedback on your spoken interview answers.'
p['ITSAppUsesNonExemptEncryption'] = False
p['UISupportedInterfaceOrientations'] = ['UIInterfaceOrientationPortrait']
p.pop('UISupportedInterfaceOrientations~ipad', None)
with open(PLIST, 'wb') as fh:
    plistlib.dump(p, fh)
print('Info.plist updated')

# 3. iPhone only (no iPad screenshots needed) and the version from package.json
pkg = json.load(open(os.path.join(APP, 'package.json')))
s = open(PBX, encoding='utf-8').read()
s, n1 = re.subn(r'TARGETED_DEVICE_FAMILY = "?[0-9,]+"?;', 'TARGETED_DEVICE_FAMILY = 1;', s)
s, n2 = re.subn(r'MARKETING_VERSION = [^;]+;', 'MARKETING_VERSION = %s;' % pkg['version'], s)
if not (n1 and n2):
    sys.exit('Could not find TARGETED_DEVICE_FAMILY / MARKETING_VERSION in project.pbxproj')
open(PBX, 'w', encoding='utf-8').write(s)
print('project: iPhone only, version %s' % pkg['version'])
