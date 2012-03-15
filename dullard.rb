require 'zip/zipfilesystem'
require 'nokogiri'

module Dullard; end

class Dullard::Workbook
  def initialize(file)
    @file = file
    @zipfs = Zip::ZipFile.open(@file)
  end

  def sheets
    workbook = Nokogiri::XML::Document.parse(@zipfs.file.open("xl/workbook.xml"))
    @sheets = workbook.css("sheet").map {|n| Dullard::Sheet.new(self, n.attr("name"), n.attr("sheetId")) }
  end

  def string_table
    @string_tabe ||= read_string_table
  end

  def read_string_table
    @string_table = []
    state = :top
    Nokogiri::XML::Reader(@zipfs.file.open("xl/sharedStrings.xml")).each do |node|
      case state
      when :top
        if node.name == "t"
          state = :entry
        end
      when :entry
        @string_table << node.value
        state = :top
      end
    end
    @string_table
  end

  def zipfs
    @zipfs
  end
end

class Dullard::Sheet
  attr_reader :name, :workbook
  def initialize(workbook, name, id)
    @workbook = workbook
    @name = name
    @id = id
  end

  def string_lookup(i)
    @workbook.string_table[i]
  end

  def rows
    Enumerator.new do |y|
      state = :top
      shared = false
      row = []
      Nokogiri::XML::Reader(@workbook.zipfs.file.open("xl/worksheets/sheet#{@id}.xml")).each do |node|
        case state
        when :top
          if node.name == "row"
            state = :row 
          end
        when :row
          if node.name == "row"
            y << row
            row = []
          else
            state = :cell
            shared = (node.attribute("t") == "s")
          end
        when :cell
          row << (shared ? string_lookup(node.value.to_i) : node.value)
          state = :row
        end
      end
      y << row
    end
  end
end

