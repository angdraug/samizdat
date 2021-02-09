# vim: et sw=2 sts=2 ts=8 tw=0

require 'rmagick'
require 'samizdat'

class Captcha
  include SiteHelper

  DEFAULT_NUMBER    = 1000
  DEFAULT_IMAGE_DIR = '/var/lib/samizdat/captcha'

  TABLE  = :captcha
  CONFIG = 'plugins/options/spam/captcha/'

  def initialize(site)
    @site = site
    c = try_config(CONFIG, {})
    @number    = c['number']    || DEFAULT_NUMBER
    @font      = c['font']      || 'DejaVu Serif'
    @image_dir = c['directory'] || DEFAULT_IMAGE_DIR
    @fontsize  = c['fontsize']  || 24 # in pixels
    @hoffset   = c['hoffset']   || @fontsize*5/6 # TODO!
    @unrotate  = c['unrotate']
    @height    = @fontsize*5/2
  end

  def create_table
    db.create_table TABLE do
      primary_key :id
      Fixnum :result
      String :filename
      Fixnum :width
      Fixnum :height
    end
    table
  end

  def table
    db[TABLE]
  end

  def get(id)
    validate_id(id) or raise RuntimeError,
      "Invalid captcha ID: #{id}"

    cache.fetch_or_add("captcha/#{id}") { table.filter(:id => id).first }
  end
  alias :[] :get

  def random
    get(rand(@number+1))
  end

  def delete_file(filename)
    filename = File.join(@image_dir, filename)
    File.delete(filename) if File.exist?(filename)
  end

  def generate_file(string, filename, min_slew=[])
    image_path = File.join(@image_dir, filename)

    @width  = @hoffset * (string.length + 1)

    granite = Magick::ImageList.new('granite:')
    image   = Magick::ImageList.new
    image.new_image(@width, @height, Magick::TextureFill.new(granite))

    gc = Magick::Draw.new

    (rand(3) + 3).times do
      gc.stroke('black') \
        .stroke_width(1 + rand(10) % 2) \
        .line(rand(@width), rand(@height), rand(@width), rand(@height))
    end

    gc.stroke_width(0) \
      .pointsize(4*@fontsize/3) \
      .text_align(Magick::CenterAlign) \
      .font_family(@font) \
      .translate(@hoffset, (@height + @fontsize)/2)

    rot = 0
    string.chars do |c|
      gc.rotate(-rot) if @unrotate
      rot = min_slew.include?(c) ? 3 - rand(7) : 10 - rand(21)
      gc.rotate(rot) \
        .text(0, rand(5) - 2 , c) \
        .translate(@hoffset, 0)
    end
    gc.draw(image)

    image.add_noise(Magick::ImpulseNoise)  \
      .quantize(4, Magick::GRAYColorspace) \
      .write(image_path)

    [@width, @height]
  end

private
  def validate_id(id)
    return nil unless id
    i = id.to_i
    return nil unless i.to_s == id.to_s and i >= 0 and i < @number
    i
  end
end
