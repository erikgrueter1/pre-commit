#!/usr/bin/env ruby

class GitDiff
  attr_reader :filenames

  def initialize
    @filenames = `git diff --cached --name-only --diff-filter=ACM`.split("\n")
  end
end

class Check
  attr_reader :diff, :exit_status, :files

  def initialize(diff)
    @diff = diff
  end

  def check
    before_run
    puts "Running \033[1;34m#{self.class}#check\e[0m: #{command}"
    report_error unless run
    after_run
  end

  def before_run
  end

  def after_run
  end

  def files
    @files ||= Array(diff.filenames)
  end

  def run
    if files.empty?
      puts "Diff does not contain relevant files. \033[0;33m [SKIPPED]\e[0m"
      true
    else
      run_command
    end
  end

  def run_command
    system(command)
  end

  def command
    raise NotImplementedError
  end

  def report_error
    raise NotImplementedError
  end

  private

  def select_files(extension:)
    @files = diff.filenames.select { |filename| File.extname(filename) == ".#{extension}" }
  end
end

class Keywords < Check
  BAD = %w(
    binding.pry
    throw
    console.log
    debugger
  )

  def run_command
    result = `#{command}`
    puts result

    report_error unless result.empty?

    result.empty?
  end

  def command
    %(git diff --cached -G"#{BAD.join('|')}" #{files.join(' ')})
  end

  def report_error
    puts "There are files that contain this keywords: #{BAD.join(', ')}.\n"
    exit 1
  end
end

class Rubocop < Check
  def before_run
    @files = select_files(extension: :rb)
  end

  def command
    "rubocop #{files.join(' ')}"
  end

  def report_error
    puts "Rubocop reported some offenses. Aborting commit"
    exit 1
  end
end

diff = GitDiff.new
[
  Keywords,
  Rubocop
].each do |klass|
  klass.new(diff).check
end
