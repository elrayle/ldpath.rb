module Ldpath
  class Transform < Parslet::Transform
    attr_reader :prefixes

    class << self
      def default_prefixes
        @default_prefixes ||= {
          "rdf"  => RDF::Vocabulary.new("http://www.w3.org/1999/02/22-rdf-syntax-ns#"),
          "rdfs" => RDF::Vocabulary.new("http://www.w3.org/2000/01/rdf-schema#"),
          "owl"  => RDF::Vocabulary.new("http://www.w3.org/2002/07/owl#"),
          "skos" => RDF::Vocabulary.new("http://www.w3.org/2004/02/skos/core#"),
          "dc"   => RDF::Vocabulary.new("http://purl.org/dc/elements/1.1/"),
          "xsd"  => RDF::Vocabulary.new("http://www.w3.org/2001/XMLSchema#"),#          (LMF base index datatypes/XML Schema)
          "lmf"  => RDF::Vocabulary.new("http://www.newmedialab.at/lmf/types/1.0/"),#    (LMF extended index datatypes)
          "fn"   => RDF::Vocabulary.new("http://www.newmedialab.at/lmf/functions/1.0/"),# (LMF index functions)
          "foaf" => RDF::Vocabulary.new("http://xmlns.com/foaf/0.1/"),
          "info" => RDF::Vocabulary.new("info:"),
          "urn" => RDF::Vocabulary.new("urn:"),
        }
      end
    end

    def apply obj, context = nil
      context ||= {}
      context[:filters] ||= []
      context[:prefixes] ||= {}.merge(self.class.default_prefixes)
      @prefixes = context[:prefixes]
      super obj, context
    end
    
    # Core types
    rule(literal: simple(:literal)) { literal.to_s }
    rule(iri: simple(:iri)) { RDF::IRI.new(iri) }
    
    # Namespaces
    rule(prefixID: subtree(:prefixID)) do
      prefixes[prefixID[:id].to_s] = RDF::Vocabulary.new(prefixID[:iri])
      nil
    end
    
    rule(prefix: simple(:prefix), localName: simple(:localName)) do
      (prefixes[prefix.to_s] || RDF::Vocabulary.new(prefix.to_s))[localName]
    end
    
    rule(filter: subtree(:filter)) do
      filters << filter[:test]
      nil
    end

    rule(boost: subtree(:boost)) do
      # no-op
      nil
    end


    # Mappings
    
    rule(mapping: subtree(:mapping)) do
      FieldMapping.new mapping[:name].to_s, mapping[:selector], mapping[:field_type]
    end

    ## Selectors
    
    
    ### Atomic Selectors
    rule(self: simple(:self)) do 
      SelfSelector.new
    end

    rule(fname: simple(:fname)) do
      FunctionSelector.new fname.to_s
    end

    rule(fname: simple(:fname), arglist: subtree(:arglist)) do
      FunctionSelector.new fname.to_s, arglist
    end
  
    rule(property: simple(:property)) do
      PropertySelector.new property
    end
    
    rule(loose: simple(:loose), property: simple(:property)) do
      LoosePropertySelector.new property
    end

    rule(wildcard: simple(:wilcard)) do
      WildcardSelector.new
    end

    rule(reverse: simple(:reverse), property: simple(:property)) do
      ReversePropertySelector.new property
    end

    rule(range: subtree(:range)) do
      case range
      when "*"
        0..Infinity
      when "+"
        1..Infinity
      when "?"
        0..1
      else
        range.fetch(:min,0).to_i..range.fetch(:max, Infinity).to_f
      end
    end
    
    rule(delegate: subtree(:delegate), repeat: simple(:repeat)) do
      RecursivePathSelector.new delegate, repeat  
    end

    rule(identifier: simple(:identifier), tap: subtree(:tap)) do
      TapSelector.new identifier.to_s, tap
    end
  
    ### Test Selectors

    rule(delegate: subtree(:delegate), test: subtree(:test)) do
      TestSelector.new delegate, test
    end

    rule(lang: simple(:lang)) do
      LanguageTest.new lang.to_s.to_sym
    end

    rule(type: simple(:type)) do
      TypeTest.new type
    end

    rule(type: simple(:type)) do
      TypeTest.new type
    end
    
    rule(not: subtree(:not_op)) do
      NotTest.new not_op[:delegate]
    end
    
    rule(and: subtree(:op)) do
      AndTest.new op[:left], op[:right]
    end
    
    rule(or: subtree(:op)) do
      OrTest.new op[:left], op[:right]
    end

    rule(is: subtree(:is)) do
      IsTest.new PropertySelector.new(is[:property]), is[:right]
    end
    
    rule(is_a: subtree(:is_a)) do
      IsTest.new PropertySelector.new(RDF.type), is_a[:right]
    end

    ### Compound Selectors
    rule(left: subtree(:left), op: simple(:op), right: subtree(:right)) do
      case op
        when "/"
          PathSelector.new left, right
        when "|"
          UnionSelector.new left, right
        when "&"
          IntersectionSelector.new left, right
      end
    end


    Infinity = 1.0 / 0.0
  end
end
