module Ldpath
  class Program
    ParseError = Class.new StandardError

    class << self
      def parse(program, transform_context = {})
        ast = transform.apply load(program), transform_context

        Ldpath::Program.new ast.compact, transform_context
      end

      def load(program)
        parser.parse(program, reporter: Parslet::ErrorReporter::Deepest.new)
      rescue Parslet::ParseFailed => e
        raise ParseError, e.cause.ascii_tree
      end

      private

      def transform
        Ldpath::Transform.new
      end

      def parser
        @parser ||= Ldpath::Parser.new
      end
    end

    attr_reader :mappings, :prefixes, :filters
    def initialize(mappings, options = {})
      @mappings ||= mappings
      @prefixes = options[:prefixes] || {}
      @filters = options[:filters] || []
    end

    def evaluate(uri, context: nil)
      result = Ldpath::Result.new(self, uri, context: context)
      unless filters.empty?
        return {} unless filters.all? { |f| f.evaluate(result, uri, result.context) }
      end

      result.to_hash
    end
  end
end
