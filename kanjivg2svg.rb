# Encoding: UTF-8
# By: Kim Ahlström <kim.ahlstrom@gmail.com>
# License: Creative Commons Attribution-Share Alike 3.0 - http://creativecommons.org/licenses/by-sa/3.0/
# KanjiVG is copyright (c) 2009/2010 Ulrich Apel and released under the Creative Commons Attribution-Share Alike 3.0

require 'rubygems'
require 'rsvg2'
require 'nokogiri'
require 'pp'

class Importer
  class KanjiVG

    WIDTH = 109 # 109 per character
    HEIGHT = 109 # 109 per character
    SVG_HEAD = "<svg width=\"__WIDTH__px\" height=\"__HEIGHT__px\" viewBox=\"0 0 __VIEW_WIDTH__px __VIEW_HEIGHT__px\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" xml:space=\"preserve\" version=\"1.1\"  baseProfile=\"full\">"
    SVG_FOOT = '</svg>'
    TEXT_STYLE = 'fill:#FF2A00;font-family:Helvetica;font-weight:normal;font-size:14;stroke-width:0'
    CURRENT_PATH_STYLE = 'fill:none;stroke:black;stroke-width:3'
    EXISTING_PATH_STYLE = 'fill:none;stroke:#999;stroke-width:3'
    BOUDING_BOX_STYLE = 'stroke:#ddd;stroke-width:2'
    GUIDE_LINE_STYLE = 'stroke:#ddd;stroke-width:2;stroke-dasharray:3 3'

    ENTRY_NAME = 'svg'
    COORD_RE = /-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/ #/(?:\d+(?:\.\d+)?)/ #%r{(?ix:\d+ (?:\.\d+)?)}
    def initialize(doc, output_dir, type = :numbers)
      @output_dir = output_dir
      @type = type

      # Don't want Nokogiri to read in the entire document at once
      # So doing it entry by entry
      tmp = ""
      begin
        while (line = doc.readline)
          if line =~ /<#{ENTRY_NAME}/
            tmp = line
          elsif line =~ /<\/#{ENTRY_NAME}>/
            tmp << line
            noko = Nokogiri::XML(tmp)
            parse(noko)
          else
            tmp << line
          end
        end
      rescue EOFError
        doc.close
      end
    end

    private

    def parse(doc)
      codepoint = nil
      entry = doc.css('g')[1]
      if entry['kvg:element'].nil?
        codepoint = entry['id'].split(':')[1].to_i(16) # get it from the id="kvg:0abcd"
      else
        codepoint = entry['kvg:element'].codepoints.first
      end
	  
      #svg = File.open("#{@output_dir}/#{codepoint}_#{@type}.svg", File::RDWR|File::TRUNC|File::CREAT)
      svg = ""
      stroke_count = 0
      stroke_total = entry.css('path[d]').length
      paths = []
	  
      fives, rest = stroke_total.divmod(5)
	  
      # Generate the header
      if @type == :frames
	    t = (stroke_total > 5) ? 5 : stroke_total
        width = (WIDTH * t)# + (2 * (stroke_total - 1))
        view_width = width
        height = rest == 0 ? HEIGHT * fives : HEIGHT * (fives+1)
        view_height = height
      else
        width = WIDTH * 1
      end
      header = SVG_HEAD.gsub('__WIDTH__', width.to_s)
      header = header.gsub('__VIEW_WIDTH__', view_width.to_s)
      header = header.gsub('__HEIGHT__', height.to_s)
      header = header.gsub('__VIEW_HEIGHT__', view_height.to_s)
      svg << "#{header}\n"

      # Guide lines
      if @type == :frames

        # outside box
        svg << line(1, 1, width - 1, 1, BOUDING_BOX_STYLE) # top
        svg << line(1, 1, 1, height - 1, BOUDING_BOX_STYLE) # left
        svg << line(1, height - 1, WIDTH * rest - 1, height - 1, BOUDING_BOX_STYLE) # bottom
        #svg << line(WIDTH * rest - 1, top, WIDTH * rest - 1, bottom, BOUDING_BOX_STYLE) # right
		
        # line separators
        (1 .. fives).each do |i|
          # draw horizontal lines for a 5er row
          svg << line(1, HEIGHT * i - 1, width - 1, HEIGHT * i - 1, BOUDING_BOX_STYLE)
        end
		
        fives, rest = stroke_total.divmod(5)

        (0 .. fives-1).each do |i|
           # vertical lines for a 5er row
           svg << line(WIDTH * 1 - 1, HEIGHT * i - 1, WIDTH * 1 - 1, HEIGHT * (i+1) - 1, BOUDING_BOX_STYLE)
           svg << line(WIDTH * 2 - 1, HEIGHT * i - 1, WIDTH * 2 - 1, HEIGHT * (i+1) - 1, BOUDING_BOX_STYLE)
           svg << line(WIDTH * 3 - 1, HEIGHT * i - 1, WIDTH * 3 - 1, HEIGHT * (i+1) - 1, BOUDING_BOX_STYLE)
           svg << line(WIDTH * 4 - 1, HEIGHT * i - 1, WIDTH * 4 - 1, HEIGHT * (i+1) - 1, BOUDING_BOX_STYLE)
           svg << line(WIDTH * 5 - 1, HEIGHT * i - 1, WIDTH * 5 - 1, HEIGHT * (i+1) - 1, BOUDING_BOX_STYLE)
           
           # horizontal grid lines
           svg << line(1, (HEIGHT/2)*(2*i+1), width - 1, (HEIGHT/2)*(2*i+1), GUIDE_LINE_STYLE)
        end
		
        # vertical grid lines
        svg << line((WIDTH/2)+(WIDTH * 0)+1, 1, (WIDTH/2)+(WIDTH * 0)+1, HEIGHT * fives, GUIDE_LINE_STYLE)
        svg << line((WIDTH/2)+(WIDTH * 1)+1, 1, (WIDTH/2)+(WIDTH * 1)+1, HEIGHT * fives, GUIDE_LINE_STYLE)
        svg << line((WIDTH/2)+(WIDTH * 2)+1, 1, (WIDTH/2)+(WIDTH * 2)+1, HEIGHT * fives, GUIDE_LINE_STYLE)
        svg << line((WIDTH/2)+(WIDTH * 3)+1, 1, (WIDTH/2)+(WIDTH * 3)+1, HEIGHT * fives, GUIDE_LINE_STYLE)
        svg << line((WIDTH/2)+(WIDTH * 4)+1, 1, (WIDTH/2)+(WIDTH * 4)+1, HEIGHT * fives, GUIDE_LINE_STYLE)

        (1 .. rest).each do |i|
          # vertical lines for last row
          svg << line(WIDTH * i - 1, HEIGHT * fives - 1, WIDTH * i - 1, HEIGHT * (fives+1) - 1, BOUDING_BOX_STYLE)
		   
          # vertical grid lines for last row
          svg << line((WIDTH/2)+(WIDTH * (i-1))+1, HEIGHT * fives, (WIDTH/2)+(WIDTH * (i-1))+1, height - 1, GUIDE_LINE_STYLE)
        end
		
        # last horizontal grid line
        svg << line(1, (HEIGHT/2)*(2*fives+1), WIDTH * rest - 1, (HEIGHT/2)*(2*fives+1), GUIDE_LINE_STYLE)

      end

      # Draw the strokes
      entry.css('path[d]').each do |stroke|
        paths << stroke['d']
        stroke_count += 1

        case @type
        when :animated
          svg << "<path d=\"#{stroke['d']}\" style=\"#{CURRENT_PATH_STYLE};opacity:0\">\n"
          svg << "  <animate attributeType=\"CSS\" attributeName=\"opacity\" from=\"0\" to=\"1\" begin=\"#{stroke_count-1}s\" dur=\"1s\" repeatCount=\"0\" fill=\"freeze\" />\n"
          svg << "</path>\n"
        when :numbers
          x, y = move_text_relative_to_path(stroke['d'])
          svg << "<text x=\"#{x}\" y=\"#{y}\" style=\"#{TEXT_STYLE}\">#{stroke_count}</text>\n"
          svg << "<path d=\"#{stroke['d']}\" style=\"#{CURRENT_PATH_STYLE}\" />\n"
        when :frames
          md = /^[LMT]\s*(#{COORD_RE})[,\s]*(#{COORD_RE})/ix.match(paths.last)
          path_start_x = md[1].to_f
          path_start_y = md[2].to_f
          path_start_x += WIDTH * (stroke_count - 1)
          
          h = 0
          w = 0
          
          paths.each_with_index do |path, i|
            isLast = ((stroke_count - 1) == i)
            delta = isLast ? WIDTH * (stroke_count - 1) : WIDTH
			
            h, asd = (stroke_count - 1).divmod(5)
            w, asd = i.divmod(5)
            #path.gsub!("M ", "M")
            
            # Move strokes relative to the frame

            path.gsub!(/([LMTm])\s*(#{COORD_RE})/x) do |m| #('^[LMT]\\s*(' + coordRe + ')[,\\s](' + coordRe + ')', 'i');
              letter = $1
              x  = $2.to_f
              x += delta
              "#{letter}#{x}"
            end
            path.gsub!(/(S)\s*(#{COORD_RE})[,\s]*(#{COORD_RE})[,\s]*(#{COORD_RE})/) do |m|
              letter = $1
              x1  = $2.to_f
              x1 += delta
              x2  = $4.to_f
              x2 += delta
              "#{letter}#{x1},#{$3},#{x2}"
            end
            path.gsub!(/((?!^)\G[-,\s]|C)\s*(#{COORD_RE})[-,\s](#{COORD_RE})[-,\s](#{COORD_RE})[-,\s](#{COORD_RE})[-,\s](#{COORD_RE})[-,\s](#{COORD_RE})/) do |m|
              letter  = $1
              x1  = $2.to_f
              x1 += delta
              x2  = $4.to_f
              x2 += delta
              x3  = $6.to_f
              x3 += delta
              "#{letter}#{x1},#{$3},#{x2},#{$5},#{x3},#{$7}"
            end


            svg << "<path d=\"#{path}\" style=\"#{isLast ? CURRENT_PATH_STYLE : EXISTING_PATH_STYLE}\" transform=\"translate(#{-WIDTH*h*5},#{HEIGHT*h})\"/>\n"
          end

          # Put a circle at the stroke start
          svg << "<circle cx=\"#{path_start_x}\" cy=\"#{path_start_y}\" r=\"5\" stroke-width=\"0\" fill=\"#FF2A00\" opacity=\"0.7\" transform=\"translate(#{-WIDTH*w*5},#{HEIGHT*w})\"/>"
          svg << "\n"
        end
      end

      svg << SVG_FOOT

      ImageConvert.save_svg_as_png(svg, width, height, "#{@output_dir}/#{codepoint}_#{@type}.png")
    end

    # TODO: make this shit really smart
    def move_text_relative_to_path(path)
      md = /^M (#{COORD_RE}) , (#{COORD_RE})/ix.match(path)
      path_start_x = md[1].to_f
      path_start_y = md[2].to_f

      text_x = path_start_x
      text_y = path_start_y

      [text_x, text_y]
    end

    def line(x1, y1, x2, y2, style)
      "<line x1=\"#{x1}\" y1=\"#{y1}\" x2=\"#{x2}\" y2=\"#{y2}\" style=\"#{style}\" />\n"
    end

  end

  class ImageConvert
  def self.save_svg_as_png(svg, width, height, destination)
    svg = RSVG::Handle.new_from_data(svg)
    width   = width  ||=500
    height  = height ||=500
    surface = Cairo::ImageSurface.new(Cairo::FORMAT_ARGB32, width, height)
    context = Cairo::Context.new(surface)
    context.render_rsvg_handle(svg)
    surface.write_to_png(destination)
  end
end

end

input_dir = ARGV[0] # Directory of .svg's
output_dir = ARGV[1] # Directory of .png's
type = ARGV[2] || 'frames' # Style of output, frames|animated|numbers

#output_dir = File.expand_path('../svgs',  __FILE__)
Dir.mkdir(output_dir) unless File.exists?(output_dir)

processed = 0
puts "Starting the conversion @ #{Time.now} ..."

Dir["#{input_dir}*.svg"].each do |file|
  begin
    Importer::KanjiVG.new(File.open(file), output_dir, type.to_sym)
  rescue => e
    puts "Failed to process file: #{file}"
    puts "\t" << e.message
    e.backtrace.each { |msg| puts "\t" << msg }
  end
  processed += 1
  if processed % 200 == 0
    puts "Processed #{processed} @ #{Time.now}"
  end
end