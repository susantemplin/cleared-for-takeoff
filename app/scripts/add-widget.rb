# Adds the "Question of the day" widget extension (TakeoffWidget) to the generated iPhone project
# and embeds it in the app. Run from the app folder after make-widget.mjs. Needs the xcodeproj gem.
require 'json'
require 'xcodeproj'

project_path = File.join('ios', 'App', 'App.xcodeproj')
version = JSON.parse(File.read('package.json'))['version']
project = Xcodeproj::Project.open(project_path)
app = project.targets.find { |t| t.name == 'App' } or abort('App target not found')
if project.targets.any? { |t| t.name == 'TakeoffWidget' }
  puts 'TakeoffWidget already in the project'
  exit 0
end

widget = project.new_target(:app_extension, 'TakeoffWidget', :ios, '17.0')
group = project.main_group.find_subpath('TakeoffWidget', true)
group.set_source_tree('<group>')
group.set_path('TakeoffWidget')
sources = %w[TakeoffWidget.swift Questions.swift].map { |f| group.new_reference(f) }
group.new_reference('Info.plist')
widget.add_file_references(sources)

widget.build_configurations.each do |c|
  s = c.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.clearedfortakeoff.app.widget'
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['INFOPLIST_FILE'] = 'TakeoffWidget/Info.plist'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['SWIFT_VERSION'] = '5.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  s['MARKETING_VERSION'] = version
  s['CURRENT_PROJECT_VERSION'] = '1'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['SKIP_INSTALL'] = 'YES'
  s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
end

app.add_dependency(widget)
embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
build_file = embed.add_file_reference(widget.product_reference, true)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

project.save
puts "TakeoffWidget added (com.clearedfortakeoff.app.widget, version #{version})"
