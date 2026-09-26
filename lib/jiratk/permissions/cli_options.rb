# frozen_string_literal: true

require 'optparse'
require_relative 'validation'

module JiraTk
  module Permissions
    # Each command accepts only the options used by its existing library operation.
    class CliOptions
      SERVICE = %i[service_url_env service_token_env].freeze
      REQUIRED = {
        'scheme' => %i[project], 'grants' => %i[scheme],
        'audit' => SERVICE + %i[account_id],
        'plan' => SERVICE + %i[operation account_id service_group_id broad_holder_json output],
        'execute' => SERVICE + %i[plan]
      }.freeze
      OPTIONAL = { 'scheme' => [], 'grants' => %i[permission], 'audit' => %i[projects format audit_output],
                   'plan' => %i[projects], 'execute' => %i[apply] }.freeze
      USAGE = <<~TEXT
        Usage: jira_permissions COMMAND [options]
          scheme --project KEY
          grants --scheme ID [--permission KEY]
          audit --account-id ID [--projects KEY,KEY] [--format matrix|json] [--audit-output PATH]
          plan --operation pah-assign-repair --account-id ID --service-group-id ID
               --broad-holder-json JSON --output PATH [--projects GEN,PAH]
          execute --plan PATH [--apply]

        audit, plan and execute also require:
          --service-url-env NAME --service-token-env NAME
        These select environment variable names; never pass credential values.
        Administrator configuration uses the existing JiraTK setup.
        Audit defaults to the full inventory and saves audit-results.md at the repository root.
        Explicit --projects produces an incomplete subset audit. JSON includes actual audit status.
        Broad-holder JSON must be explicit null or a JSON string (including "").
        Plan output must be a new file. Execute previews unless --apply is present.
        Inspect uncertain prior writes before rerunning; execution receipts cannot be loaded.
        Exit: 0 success; 1 audit mismatch; 2 input, precondition, incomplete audit or file failure;
              3 execution stopped after a write attempt.
      TEXT

      def self.parse(command, args)
        raise Error, 'Unknown permission command; use --help' unless REQUIRED.key?(command)

        options = {}
        parser(command, options).parse!(args)
        unless args.empty? && (REQUIRED.fetch(command) - options.keys).empty?
          raise Error, 'Missing required options or unexpected arguments; use --help'
        end

        { format: 'matrix', apply: false }.merge(options)
      end

      def self.parser(command, options)
        OptionParser.new do |parser|
          parser.require_exact = true
          (REQUIRED.fetch(command) + OPTIONAL.fetch(command)).each do |key|
            switch = key == :apply ? '--apply' : "--#{key.to_s.tr('_', '-')} VALUE"
            parser.on(switch, *types(key)) do |value|
              raise Error, 'Repeated command option' if options.key?(key)

              options[key] = value
            end
          end
        end
      end

      def self.types(key)
        case key
        when :projects then [Array]
        when :format then [%w[matrix json]]
        else []
        end
      end
      private_class_method :parser, :types
    end
  end
end
