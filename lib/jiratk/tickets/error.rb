# frozen_string_literal: true

module JiraTk
  module Tickets
    # Safe to display; never includes raw transport messages or responses.
    class Error < StandardError; end
  end
end
