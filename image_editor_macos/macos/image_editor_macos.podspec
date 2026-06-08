Pod::Spec.new do |s|
  s.name = 'image_editor_macos'
  s.version = '0.1.0'
  s.summary = 'macOS implementation of the image_editor plugin.'
  s.description = 'Provides macOS native clipboard support for image_editor.'
  s.homepage = 'https://example.com'
  s.license = { :type => 'MIT' }
  s.author = { 'GoodCleanShot' => 'dev@example.com' }
  s.source = { :path => '.' }
  s.source_files = 'image_editor_macos/Sources/image_editor_macos/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.14'
  s.swift_version = '5.0'
end
