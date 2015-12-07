guard :minitest do
  # with Minitest::Spec
  watch(%r{^spec/(.*)_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})         { |m| "spec/#{m[1]}_spec.rb" }
  watch(%r{^spec/spec_helper\.rb$}) { 'spec' }
end

guard 'rake', :task => 'assets:precompile' do
  watch(%r{^vendor/assets/.+/.+\..+})
end

guard 'puma' do
  watch('Gemfile.lock')
  watch(%r{^config|lib|routes|helpers/.*})
end
