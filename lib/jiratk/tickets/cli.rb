# frozen_string_literal: true

require 'optparse'
require_relative 'client'

module JiraTk
  module Tickets
    # Small command interface; section text is data, never executable Ruby.
    class Cli
      USAGE = <<~TEXT
        Usage:
          jira_ticket get KEY
          jira_ticket append-description KEY --heading TEXT --file PATH [--apply]
          jira_ticket create-task PROJECT --summary TEXT --label UNIQUE_LABEL --file PATH [--apply]
            [--parent KEY] creates a Sub-task under a verified parent in PROJECT.

        Append previews by default. --apply rechecks the ticket, writes only its
        description, and reads it back. Repeating an exact section is a no-op.
        The file contains plain text, with blank lines separating paragraphs.
        Creation previews by default and checks a unique label for duplicates.
        Search can lag behind writes: inspect uncertain creates before retrying.
      TEXT

      def initialize(client: nil, out: $stdout, err: $stderr)
        @client = client
        @out = out
        @err = err
      end

      def run(argv)
        return help if argv.empty? || %w[help --help -h].include?(argv.first)

        @out.puts JSON.pretty_generate(dispatch(argv.dup))
        0
      rescue Error, OptionParser::ParseError => e
        @err.puts e.message
        1
      rescue SystemCallError, IOError
        @err.puts 'Unable to read section file'
        1
      end

      private

      def help
        @out.puts USAGE
        0
      end

      def client
        @client ||= Client.new
      end

      def dispatch(args)
        command, key = args.shift(2)
        case command
        when 'get'
          raise Error, USAGE unless key && args.empty?

          client.get(key)
        when 'append-description'
          append_description(key, args)
        when 'create-task'
          create_task(key, args)
        else
          raise Error, USAGE
        end
      end

      def append_description(key, args)
        options = parse_append(args)
        raise Error, USAGE unless key && args.empty? && options[:heading] && options[:file]

        client.append_description(key, text: read_text(options.delete(:file)), **options)
      end

      def create_task(project, args)
        options = parse_create(args)
        raise Error, USAGE unless project && args.empty? && %i[summary label file].all? { |name| options.key?(name) }

        client.create_task(project, text: read_text(options.delete(:file)), **options)
      end

      def read_text(path)
        text = File.read(path, encoding: 'UTF-8')
        raise Error, 'Section file must contain valid UTF-8' unless text.valid_encoding?

        text
      end

      def parse_create(args)
        options = { apply: false }
        OptionParser.new do |parser|
          parser.on('--summary TEXT') { |value| options[:summary] = value }
          parser.on('--label LABEL') { |value| options[:label] = value }
          parser.on('--file PATH') { |value| options[:file] = value }
          parser.on('--parent KEY') { |value| options[:parent] = value }
          parser.on('--apply') { options[:apply] = true }
        end.parse!(args)
        options
      end

      def parse_append(args)
        options = { apply: false }
        OptionParser.new do |parser|
          parser.on('--heading TEXT') { |value| options[:heading] = value }
          parser.on('--file PATH') { |value| options[:file] = value }
          parser.on('--apply') { options[:apply] = true }
        end.parse!(args)
        options
      end
    end
  end
end
