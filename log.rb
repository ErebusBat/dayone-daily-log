#!/usr/bin/env ruby
############################################
# Appends to the daily log entry in DayOne
############################################

require 'rubygems'
require 'bundler'
Bundler.require
require 'date'
require 'pathname'
require 'fileutils'
require 'pry'

# https://github.com/jyruzicka/rb-dayone

# Gets or creates the daily log entry for given date
def find_or_create_entry date=Date.today
	search = DayOne::Search.new do
		tag.include "dailylog"
		creation_date.after date.to_time
		creation_date.before (date+1).to_time
	end
	entry = search.results.first

	# Detect if we have found a sync conflict file and stop so we don't pull out
	# our hair wondering why our changes are not working.
	if entry && entry.file =~ /conflict/i
		msg = ['','*'*80]
		msg << "The found entry is in a conflcited state, please fix!"
		msg << "   UUID: #{entry.uuid}"
		msg << "   Path: #{entry.file}"
		msg << '*'*80
		raise msg.join("\n")
	end

	# Create it if need be
	unless entry
		entry = DayOne::Entry.new "Daily Log, #{date.strftime('%A')}\n"
	end

	# Return the entry
	entry
end

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

def append_to_daily_log text,summary=nil, quite=false
	raise "Not appending empty text to entry!" if text.to_s.empty?
	entry_text = get_text_to_append(text,summary)
	entry      = find_or_create_entry
	# binding.pry
	entry.entry_text += entry_text
	entry.create!
	puts "Added the following entry to your log:#{entry_text}"
end

def main
	text = nil
	summary = nil
	if ARGV.size >= 1
		text = ARGV[0]
	end
	if ARGV.size == 2
		summary = ARGV[1]
	end

	# Check to see if we need to do a file
	tmp_file = nil
	if text.to_s =~ /^\s*$/
		tmp_file = Pathname.new("/tmp/daily_log_entry.md") # Use MD ext for syntax highlighting
		if !tmp_file.file?
			FileUtils.touch tmp_file
		end
		`subl -n -w #{tmp_file}`
		text = tmp_file.read.chomp
		if text !~ /[^[:space:]]/  # From Rails String.blank? https://github.com/rails/rails/blob/f4e180578c673194f58d4ff5a4a656cc51b2249e/activesupport/lib/active_support/core_ext/object/blank.rb#L91
			$stderr.puts "File empty, aborting"
			exit 1
		end
	end
	append_to_daily_log text, summary
	tmp_file.delete if tmp_file   # Cleanup
end

main if __FILE__ == $0
