namespace :package_manager do
  desc 'Prepare tests'
  task :prepare do
  end

  desc 'Builds the project with the Swift Package Manager'
  task spm: :prepare do
    run_test()
  end
end

desc 'Run the tests'
task :test do
  Rake::Task['package_manager:spm'].invoke
end

task default: 'test'

private

def run_test()
    sh("xcodebuild clean build test -workspace .swiftpm/xcode/package.xcworkspace -scheme DecodableRequest | xcpretty")
    test_failed("SPM") unless $?.success?
end

def test_failed(platform)
  puts "#{platform} build failed"
  exit $?.exitstatus
end

#sh("xcodebuild \"-workspace\" \".swiftpm/xcode/package.xcworkspace\" \"-scheme\" \"DecodableRequest\" \"build\" \"test\" ") rescue nil
#package_manager_failed('Swift Package Manager') unless $?.success?

