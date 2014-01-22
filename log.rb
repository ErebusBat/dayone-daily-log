#!/usr/bin/env ruby
################################################################################
# Appends to the daily log entry in DayOne
# 	Requires the rb-dayone gem by jyruzicka:
# 	https://github.com/jyruzicka/rb-dayone
#
# This script has two modes.  A quick add mode:
# 	dlog 'Quick Snippet'
# and editor:
# 	dlog   (Will open an editor and append
# 			the entry to your daily log)
################################################################################

require 'rubygems'
require 'bundler'
Bundler.require
require 'date'
require 'pathname'
require 'fileutils'
require 'optparse'
require 'ostruct'

# Tag to locate the DailyLog type entries.
ENTRY_TAG="dailylog"

# Gets or creates the daily log entry for given date (today)
def find_or_create_entry date=Date.today
	search = DayOne::Search.new do
		tag.include ENTRY_TAG
		creation_date.after date.to_time
		creation_date.before (date+1).to_time
	end
	entry = search.results.first

	# Detect if we have found a dropbox sync conflict file and stop so we don't
	# pull out our hair wondering why our changes are not working.
	if entry && entry.file =~ /conflict/i
		msg = ['','*'*80]
		msg << "The found entry is in a conflcited state, please fix!"
		msg << "   UUID: #{entry.uuid}"
		msg << "   Path: #{entry.file}"
		msg << '*'*80
		raise msg.join("\n")
	end

	# Create the daily entry if need be
	unless entry
		entry = DayOne::Entry.new "Daily Log, #{date.strftime('%A')}\n"
		entry.tags << ENTRY_TAG
		entry
	end

	# Return the entry
	entry
end

# Gets a markdown formatted string from the given text,summary and date
def get_text_to_append text,summary=nil,date=DateTime.now
	date = Time.parse(date) unless date.respond_to? :strftime
	if !summary.to_s.empty?
		summary = "**#{summary}**"
		text = summary + "\n" + text
	end
	%Q{

### #{date.strftime('%H:%M')}
#{text}}
end

# One-stop-shop to find/create entry and append formatted text
def append_to_daily_log text,summary=nil, entry=nil
	raise "Not appending empty text to entry!" if text.to_s.empty?
	entry_text = get_text_to_append(text,summary)
	entry      = find_or_create_entry unless entry
	# binding.pry
	entry.entry_text += entry_text
	entry.create!
	puts "Added the following entry to your log:#{entry_text}"
end

# Option parser
def get_options
	options = OpenStruct.new({
		 action: :append,
		   text: '',
		summary: '',
	})
	parser  = OptionParser.new do |opts|
		# opts.banner = %Q{Usage: dlog [text] [summary]}

		opts.on('--edit', "Edit todays log entry in DayOne") do |v|
			options.action = :edit
		end
	end
	parser.parse! ARGV

	if options.action == :append
		if ARGV.size >= 1
			options.text = ARGV[0]
		end
		if ARGV.size == 2
			# Can specify a summary as second argument that will be bolded.
			options.summary = ARGV[1]
		end

		if options.text.to_s =~ /^\s*$/
			options.action = :external_edit
		end
	end

	options
end

# Entry point
def main
	opts = get_options

	if opts.action == :edit
		entry = find_or_create_entry
		append_to_daily_log " ", nil, entry
		`open "dayone://edit?entryId=#{entry.uuid}"`
		Kernel.exit 0
	elsif opts.action == :external_edit
		tmp_file = Pathname.new("/tmp/daily_log_entry.md") # Use MD ext for syntax highlighting
		FileUtils.touch tmp_file unless tmp_file.file?
		# We should probably make this customizable, pull req?
		`subl -n -w #{tmp_file}`
		text = tmp_file.read.chomp

		# if they didn't type anything then don't append empty string
		if text !~ /[^[:space:]]/  # From Rails String.blank? https://github.com/rails/rails/blob/f4e180578c673194f58d4ff5a4a656cc51b2249e/activesupport/lib/active_support/core_ext/object/blank.rb#L91
			$stderr.puts "File empty, aborting"
			exit 1
		end
		opts.tmp_file = tmp_file
	end

	append_to_daily_log opts.text, opts.summary
	tmp_file.delete if opts.tmp_file   # Cleanup
end

# Only act as a script if we were invoked directly
main if __FILE__ == $0
