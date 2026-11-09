# Adds the app's own native Swift files (app/ios-native) to the generated iPhone project
# and makes the main screen use TakeoffViewController, which registers them.
# Run from the app folder after `npx cap add ios`. Needs the xcodeproj gem.
require 'fileutils'
require 'xcodeproj'
require 'json'

src = 'ios-native'
dest = File.join('ios', 'App', 'App')
files = Dir[File.join(src, '*.swift')].map { |f| File.basename(f) }.sort
abort('no Swift files in ios-native') if files.empty?
files.each { |f| FileUtils.cp(File.join(src, f), File.join(dest, f)) }

project = Xcodeproj::Project.open(File.join('ios', 'App', 'App.xcodeproj'))
app = project.targets.find { |t| t.name == 'App' } or abort('App target not found')
group = project.main_group.find_subpath('App', false) or abort('App group not found')
files.each do |f|
  next if group.files.any? { |r| r.path == f }
  app.add_file_references([group.new_reference(f)])
end
project.save

sb = File.join(dest, 'Base.lproj', 'Main.storyboard')
xml = File.read(sb)
abort('Main.storyboard: CAPBridgeViewController not found') unless xml.include?('customClass="CAPBridgeViewController"')
xml = xml.sub(/customClass="CAPBridgeViewController"\s+customModule="Capacitor"/, 'customClass="TakeoffViewController" customModule="App" customModuleProvider="target"')
xml = xml.sub('customClass="CAPBridgeViewController"', 'customClass="TakeoffViewController" customModule="App" customModuleProvider="target"') if xml.include?('customClass="CAPBridgeViewController"')
File.write(sb, xml)
abort('storyboard not updated') unless File.read(sb).include?('TakeoffViewController')
# Capacitor builds the app's plugin list at startup from capacitor.config.json (packageClassList),
# before the main screen's capacitorDidLoad, so list our own plugin there too.
cfg = File.join(dest, 'capacitor.config.json')
abort('capacitor.config.json not found (run cap sync first)') unless File.exist?(cfg)
j = JSON.parse(File.read(cfg))
list = (j['packageClassList'] ||= [])
list << 'TakeoffSpeechPlugin' unless list.include?('TakeoffSpeechPlugin')
File.write(cfg, JSON.pretty_generate(j))
abort('packageClassList not updated') unless JSON.parse(File.read(cfg))['packageClassList'].include?('TakeoffSpeechPlugin')
puts "packageClassList: #{list.join(', ')}"
puts "Native files added: #{files.join(', ')}; main screen = TakeoffViewController"
