require 'fileutils'
require 'English'

namespace :pkg do
  desc 'Create DEB package with `debuild`.'
  task :deb do
    # copy 'debian' directory from 'extras' into main directory
    FileUtils.cp_r 'extras/debian/', Rake.application.original_dir + '/debian'

    # run 'debuild'
    system 'debuild'

    if $CHILD_STATUS == 0
      # remove 'debian' directory
      FileUtils.rm_r Rake.application.original_dir + '/debian', :force => true
    else
      abort 'Error while building the DEB package with `debuild`. Please check the output.'
    end
  end

  desc 'Generate package source tar.bz2, supply ref=<tag> for tags'
  task :generate_source do
    File.exist?('pkg') || FileUtils.mkdir('pkg')
    ref = ENV['ref'] || 'HEAD'
    name = 'foreman'
    version = `git show #{ref}:VERSION`.chomp
    raise "can't find VERSION from #{ref}" if version.empty?

    filename = "pkg/#{name}-#{version}.tar.bz2"
    `git archive --prefix=#{name}-#{version}/ #{ref} | bzip2 -9 > #{filename}`
    raise 'Failed to generate the source archive' if $CHILD_STATUS != 0

    Dir.chdir('pkg') do
      `bunzip2 *.tar.bz2`
      `tar -xf *.tar`
    end

    `npm install`
    `NODE_ENV=production node_modules/.bin/webpack --bail --config config/webpack.config.js`

    Dir.chdir('pkg') do
      `mv ../package-lock.json foreman-#{version}/`
      `mv ../public/webpack foreman-#{version}/public`
    end

    Dir.chdir('pkg') do
      `tar -cvf foreman-#{version}.tar foreman-#{version}`
      `bzip2 foreman-#{version}.tar`
    end

    Dir.chdir('pkg') do
      `mkdir foreman-node-modules-#{version}`
      `mv ../node_modules foreman-node-modules-#{version}/`
      `cp ../package.json foreman-node-modules-#{version}/`
      `tar -cvf foreman-node-modules-#{version}.tar foreman-node-modules-#{version}`
      `bzip2 foreman-node-modules-#{version}.tar`
    end

    Dir.chdir('pkg') do
      `rm -rf foreman-#{version}`
      `rm -rf foreman-node-modules-#{version}`
    end
  end
end
