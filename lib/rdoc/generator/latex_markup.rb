# -*- coding: utf-8 -*-

#Mixin module mixed into RDoc::CodeObject and RDoc::Context::Section
#to overwrite RDoc’s standard RDoc::Generator::Markup mixin module that
#forces RDoc to HTML output. This module forces RDoc to LaTeX output ;-).
module RDoc::Generator::LaTeX_Markup

  #Create an unique label for this CodeObject.
  #==Return value
  #A string (hopefully) uniquely identifying this CodeObject. Inteded for
  #use as the reference in a <tt>\href</tt> command.
  #==Raises
  #[PDF_LaTeX_Error] +self+ isn’t a CodeObject (→ Context::Section).
  def latex_label
    case self
    when RDoc::Context then "class-module-#{full_name}"
    when RDoc::MethodAttr then "method-attr-#{full_name.gsub('#', '+')}" # '#' doesn’t work in references
    when RDoc::Constant then "const-#{parent.full_name}::#{name}"
    else
      raise(RDoc::Generator::PDF_LaTeX::PDF_LaTeX_Error, "Unrecognized token: #{self.inspect}!")
    end
  end

  #Calls a method of this CodeObject and passes the return value
  #to RDoc::Markup::ToLaTeX#escape.
  #==Parameter
  #[symbol] The symbol of the method (or attribute getter, same in Ruby) to call.
  #[*args]  Any arguments to pass to the method.
  #[&block] A block to pass to the method.
  #==Return value
  #A string from which everything LaTeXnically dangerous has been escaped.
  #==Raises
  #[NoMethodError] You passed a +symbol+ of an undefined method.
  def latexized(symbol, *args, &block)
    if respond_to?(symbol)
      formatter.escape(send(symbol, *args, &block).to_s) #formatter method defined below
    else
      raise(NoMethodError, "Requested call to unknown method #{self.class}##{symbol} to be latexized!")
    end
  end
  
  #Instanciates the LaTeX formatter if it is necessary and stores it
  #in an instance variable @formatter. 
  #==Return value
  #Returns the newly instanciated or already stored LaTeX formatter.
  def formatter
    return @formatter if defined?(@formatter)

    @formatter = RDoc::Markup::ToLaTeX_Crossref.new(self.kind_of?(RDoc::Context) ? self : @parent, #Thanks to RDoc for this
                                                    RDoc::RDoc.current.options.show_hash,
                                                    current_heading_level,
                                                    RDoc::RDoc.current.options.hyperlink_all)
  end
  
  #Heading depth the formatter is currently in. This is added to
  #any heading request the processed markup mades in order to ensure
  #that the correct LaTeX heading order is always preserved. For example,
  #if the user orders a level 2 heading in a file (the README for instance),
  #he gets a larger heading as if he had ordered a level 2 heading inside a
  #method description.
  def current_heading_level
    case self
    when RDoc::TopLevel then 0
    when RDoc::ClassModule then 0 #Never-ever use level 1 headings apart from TopLevels...
    when RDoc::MethodAttr, RDoc::Alias, RDoc::Constant, RDoc::Include then 3
    else
      0
    end
  end
end

#FIXME:
#This *doesn't* overwrite the inclusion in the subclasses that
#RDoc::Generator::Markup does!! Therefore I need to monkeypatch
#the subclasses affected by the monkeypatch in markup.rb (RDoc::
#Generator::Markup) as well! YEAH, workarounds for the workarounds!

#class RDoc::CodeObject
#  include RDoc::Generator::LaTeX_Markup
#end

#Note that RDoc::Context::Section is special, as it doesn't inherit
#from RDoc::CodeObject. For the rest, refer to the comment above.
[RDoc::Context::Section, RDoc::AnyMethod, RDoc::Attr, RDoc::Include, RDoc::Alias, RDoc::Constant, RDoc::Context].each do |klass|
  klass.send(:include, RDoc::Generator::LaTeX_Markup) #private method
end

class RDoc::Constant

  #No more characters than specified here will be shown
  #as a constant’s value. If the content is longer, an
  #ellipsis will be put at the end of the value.
  LATEX_VALUE_LENGTH = 10

  #Shortens the value to LATEX_VALUE_LENGTH characters (plus ellipsis ...)
  #and escapes all LaTeX control characters.
  def latexized_value
    if value.chars.count > LATEX_VALUE_LENGTH
      str = formatter.escape(value.chars.first(LATEX_VALUE_LENGTH).join) + "\\ldots"
    else
      str = formatter.escape(value)
    end
    str
  end
end
