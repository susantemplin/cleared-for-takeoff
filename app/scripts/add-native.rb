# Adds the app's own native Swift files (app/ios-native) to the generated iPhone project
# and makes the main screen use TakeoffViewController, which registers them.
# Run from the app folder after `npx cap add ios`. Needs the xcodeproj gem.
require 'fileutils'
require 'xcodeproj'

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
puts "Native files added: #{files.join(', ')}; main screen = TakeoffViewController"
