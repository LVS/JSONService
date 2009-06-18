# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{JSONService}
  s.version = "0.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["LVS"]
  s.date = %q{2009-06-18}
  s.email = %q{info@lvs.co.uk}
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    "JSONService.gemspec",
     "LICENSE",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "lib/json_service.rb",
     "lib/lvs/json_service/base.rb",
     "lib/lvs/json_service/logger.rb",
     "lib/lvs/json_service/request.rb",
     "spec/fixtures/error_response.yml",
     "spec/fixtures/response.yml",
     "spec/json_service_spec.rb",
     "spec/lvs/json_service/base_spec.rb",
     "spec/lvs/json_service/logger_spec.rb",
     "spec/lvs/json_service/request_spec.rb",
     "spec/spec.opts",
     "spec/spec_helper.rb"
  ]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/lvs/JSONService}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{A Ruby library for interacting with external JSON services}
  s.test_files = [
    "spec/lvs/json_service/base_spec.rb",
     "spec/lvs/json_service/logger_spec.rb",
     "spec/lvs/json_service/request_spec.rb",
     "spec/spec_helper.rb",
     "spec/json_service_spec.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
