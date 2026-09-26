# frozen_string_literal: true

require_relative '../permissions'
require_relative 'cli_options'
require_relative 'persistence'

module JiraTk
  module Permissions
    # The CLI owns presentation and persistence; domain checks remain in the library.
    class Cli
      def initialize(out: $stdout, err: $stderr, environment: ENV, administrator_connection: nil, persistence: nil)
        @out = out
        @err = err
        @environment = environment
        @administrator_connection = administrator_connection
        @persistence = persistence
      end

      def run(argv)
        return help if argv.empty? || %w[help --help -h].include?(argv.first)

        command, *args = argv
        options = CliOptions.parse(command, args)
        send("run_#{command}", options)
      rescue Error => e
        failure(e.message)
      rescue OptionParser::ParseError, JSON::ParserError, ArgumentError
        failure('Invalid command options or file contents; use --help')
      rescue SystemCallError, IOError
        failure('Unable to read or write command file')
      end

      def inspect
        "#<#{self.class}>"
      end

      private

      def help
        @out.puts CliOptions::USAGE
        0
      end

      def failure(message)
        @err.puts message
        2
      end

      def administrator_connection
        @administrator_connection ||= Connection.administrator
      end

      def administrator
        Client.new(connection: administrator_connection)
      end

      def service(options)
        values = CliOptions::SERVICE.map do |key|
          name = options.fetch(key)
          raise Error, 'Expected an environment variable name' unless /\A[A-Za-z_][A-Za-z0-9_]*\z/.match?(name)

          @environment.fetch(name, nil)
        end
        Client.new(connection: Connection.service_account(base_url: values[0], token: values[1]))
      end

      def json(data)
        @out.puts JSON.pretty_generate(data)
        0
      end

      def run_scheme(options)
        scheme = administrator.project_scheme(options.fetch(:project))
        json('id' => scheme.id, 'name' => scheme.name, 'grants' => scheme.grants)
      end

      def run_grants(options)
        grants = administrator.grants(options.fetch(:scheme))
        grants.select! { |grant| grant['permission'] == options[:permission] } if options.key?(:permission)
        json(grants)
      end

      def run_audit(options)
        report = Auditor.new(administrator: administrator, audit_client: service(options),
                             expected_account_id: options.fetch(:account_id)).audit(projects: options[:projects])
        @out.puts(options[:format] == 'json' ? JSON.pretty_generate(report.to_h) : report.matrix)
        save_audit(report, options)
        report.exit_status
      end

      def save_audit(report, options)
        path = options.fetch(:audit_output, MarkdownFile::DEFAULT_PATH)
        store = @persistence || Persistence.new(adapter: MarkdownFile.new(path: path))
        store.save(report)
      end

      def run_plan(options)
        raise Error, 'Only pah-assign-repair planning is supported' unless options[:operation] == 'pah-assign-repair'

        request = options.slice(:account_id, :service_group_id, :projects)
                         .merge(broad_holder_id: JSON.parse(options.fetch(:broad_holder_json)))
        plan = Planner.new(administrator: administrator, audit_client: service(options)).pah_assign_repair(**request)
        File.write(options.fetch(:output), plan.dump, mode: 'wx', perm: 0o600)
        json(plan.to_h)
      end

      def run_execute(options)
        plan = Plan.load(File.read(options.fetch(:plan), encoding: 'UTF-8'))
        result = Executor.new(administrator_connection: administrator_connection,
                              audit_client: service(options)).execute(plan, apply: options[:apply])
        json(result.to_h)
        result.to_h.fetch('exit_status')
      end
    end
  end
end
