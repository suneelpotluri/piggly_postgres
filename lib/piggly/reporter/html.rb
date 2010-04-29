module Piggly
  module Reporter
    class Html < Reporter::AbstractReporter
      autoload :DSL,    'piggly/reporter/html/dsl'
      autoload :Index,  'piggly/reporter/html/index'

      extend Piggly::Reporter::Html::DSL

      class << self
        def output(procedure, html, lines)
          File.open(report_path(procedure.source_path, '.html'), 'w') do |io|
            html(io) do

              tag :html, :xmlns => 'http://www.w3.org/1999/xhtml' do
                tag :head do
                  tag :title, "Code Coverage: #{procedure.name}"
                  tag :link, :rel => 'stylesheet', :type => 'text/css', :href => 'piggly.css'
                end

                tag :body do
                  aggregate(procedure.name, Piggly::Profile.instance.summary(procedure))

                  tag :div, :class => 'listing' do
                    tag :table do
                      tag :tr do
                        tag :td, '&nbsp;', :class => 'signature'
                        tag :td, signature(procedure), :class => 'signature'
                      end
                      tag :tr do
                        tag :td, lines.to_a.map{|n| %[<a href="#L#{n}" id="L#{n}">#{n}</a>] }.join("\n"), :class => 'lines'
                        tag :td, html, :class => 'code'
                      end
                    end
                  end

                  toc(Piggly::Profile.instance[procedure])

                  timestamp
                end
              end

            end
          end
        end

        def signature(procedure)
          string = "<span class='tK'>CREATE FUNCTION</span> <b><span class='tI'>#{procedure.name}</span></b>"
          modes  = {'i' => 'IN', 'o' => 'OUT', 'b' => 'INOUT'}

          if procedure.arg_names.size <= 1
            string   << " ( "
            separator = ", "
            spacer    = " "
          else
            string   << "\n\t( "
            separator = ",\n\t  "
            spacer    = "\t"
          end

          arguments = procedure.arg_names.zip(procedure.arg_modes, procedure.arg_types).map do |name, mode, type|
            if mode = modes[mode]
              mode = "<span class='tK'>#{mode}</span>#{spacer}"
            end
            "#{mode}<span class='tI'>#{name}</span>#{spacer}<span class='tD'>#{type}</span>"
          end.join(separator)

          string << arguments << " )"
          string << "\n<span class='tK'>SECURITY DEFINER</span>" if procedure.secdef
          string << "\n<span class='tK'>STRICT</span>" if procedure.strict
          string << "\n<span class='tK'>RETURNS#{procedure.setof ? ' SETOF' : ''}</span>"
          string << " <span class='tD'>#{procedure.rettype}</span>"

          string
        end

        def toc(tags)
          todo = tags.reject{|t| t.complete? }
          
          tag :div, :class => 'toc' do
            tag :a, 'Index', :href => 'index.html'

            unless todo.empty?
              tag :ol do
                todo.each do |t|
                  tag(:li, :class => t.type) { tag :a, t.description, :href => "#T#{t.id}" }
                end
              end
            end
          end
        end

        def timestamp
          tag :div, "Generated by piggly #{Piggly::VERSION} at #{Time.now.strftime('%B %d, %Y %H:%M %Z')}", :class => 'timestamp'
        end

        def aggregate(label, summary)
          tag :p, label, :class => 'summary'
          tag :table, :class => 'summary sortable' do
            tag :tr do
              tag :th, 'Blocks'
              tag :th, 'Loops'
              tag :th, 'Branches'
              tag :th, 'Block Coverage'
              tag :th, 'Loop Coverage'
              tag :th, 'Branch Coverage'
            end

            tag :tr, :class => 'even' do
              unless summary.include?(:block) or summary.include?(:loop) or summary.include?(:branch)
                # PigglyParser couldn't parse this file
                tag(:td, :class => 'count') { tag :span, -1, :style => 'display:none' }
                tag(:td, :class => 'count') { tag :span, -1, :style => 'display:none' }
                tag(:td, :class => 'count') { tag :span, -1, :style => 'display:none' }
                tag(:td, :class => 'pct') { tag :span, -1, :style => 'display:none' }
                tag(:td, :class => 'pct') { tag :span, -1, :style => 'display:none' }
                tag(:td, :class => 'pct') { tag :span, -1, :style => 'display:none' }
              else
                tag :td, (summary[:block][:count]  || 0), :class => 'count'
                tag :td, (summary[:loop][:count]   || 0), :class => 'count'
                tag :td, (summary[:branch][:count] || 0), :class => 'count'
                tag(:td, :class => 'pct') { percent(summary[:block][:percent])  }
                tag(:td, :class => 'pct') { percent(summary[:loop][:percent])   }
                tag(:td, :class => 'pct') { percent(summary[:branch][:percent]) }
              end
            end
          end
        end

        def table(procedures)
          tag :table, :class => 'summary sortable' do
            tag :tr do
              tag :th, 'Procedure'
              tag :th, 'Blocks'
              tag :th, 'Loops'
              tag :th, 'Branches'
              tag :th, 'Block Coverage'
              tag :th, 'Loop Coverage'
              tag :th, 'Branch Coverage'
            end

            index = Piggly::Dumper::Index.instance

            procedures.each_with_index do |procedure, k|
              summary = Piggly::Profile.instance.summary(procedure)
              row     = k.modulo(2) == 0 ? 'even' : 'odd'
              label   = index.label(procedure)

              tag :tr, :class => row do
                unless summary.include?(:block) or summary.include?(:loop) or summary.include?(:branch)
                  # PigglyParser couldn't parse this file
                  tag :td, label, :class => 'file fail'
                  tag(:td, :class => 'count') { tag :span, -1, :style => 'display:none' }
                  tag(:td, :class => 'count') { tag :span, -1, :style => 'display:none' }
                  tag(:td, :class => 'count') { tag :span, -1, :style => 'display:none' }
                  tag(:td, :class => 'pct') { tag :span, -1, :style => 'display:none' }
                  tag(:td, :class => 'pct') { tag :span, -1, :style => 'display:none' }
                  tag(:td, :class => 'pct') { tag :span, -1, :style => 'display:none' }
                else
                  tag(:td, :class => 'file') { tag :a, label, :href => procedure.identifier + '.html' }
                  tag :td, (summary[:block][:count]  || 0), :class => 'count'
                  tag :td, (summary[:loop][:count]   || 0), :class => 'count'
                  tag :td, (summary[:branch][:count] || 0), :class => 'count'
                  tag(:td, :class => 'pct') { percent(summary[:block][:percent])  }
                  tag(:td, :class => 'pct') { percent(summary[:loop][:percent])   }
                  tag(:td, :class => 'pct') { percent(summary[:branch][:percent]) }
                end
              end

            end
          end
        end

        def percent(pct)
          if pct
            tag :table, :align => 'center' do
              tag :tr do

                tag :td, '%0.2f%%&nbsp;' % pct, :class => 'num'
                tag :td, :class => 'graph' do
                  if pct
                    tag :table, :align => 'right', :class => 'graph' do
                      tag :tr do
                        tag :td, :class => 'covered', :width => (pct/2.0).to_i
                        tag :td, :class => 'uncovered', :width => ((100-pct)/2.0).to_i
                      end
                    end
                  end
                end

              end
            end
          else
            tag :span, -1, :style => 'display:none'
          end
        end
      end

    end
  end
end
