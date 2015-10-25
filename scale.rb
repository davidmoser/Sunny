require 'solar_integration/progress.rb'
require 'sketchup.rb'

class Scale < JsonSerialization
  attr_reader :color_by_relative_value

  class ColorCache
    def initialize(color1, color2)
      @cache = Hash.new
      @color1 = color1
      @color2 = color2
    end

    def get(s)
      s = s.round(2)
      if not @cache.has_key? s
        @cache[s] = Sketchup::Color.new(@color1).blend(@color2, s)
      end
      return @cache[s]
    end
  end

  def initialize(irradiance_statistics)
    @color_gradient = false
    @color_by_relative_value = true
    @color1 = [255, 255, 0]
    @color2 = [255, 0, 0]
    @color3 = [0, 0, 255]
    @color1value = 100
    @color2value = 80
    @color3value = 60
    # volatile
    @current_hash = ''
    @irradiance_statistics = irradiance_statistics
    @skip_variables = ['@current_hash', '@irradiance_statistics', '@cache1', '@cache2']
    init_caches
  end

  def update_from_hash(hash)
    unless @current_hash==hash
      initializing = @current_hash==''
      @current_hash = hash
      super(hash)
      init_caches
      if not initializing
        update_tile_colors
      end
    end
  end

  def init_caches
    @cache1 = ColorCache.new(@color2, @color3)
    @cache2 = ColorCache.new(@color1, @color2)
  end

  def recolor(face)
    if @color_by_relative_value
      value = face_property(face, 'relative_irradiance')
    else
      value = 100 * face_property(face, 'irradiance') / @irradiance_statistics.max_irradiance
    end

    value = step_value(value) if not @color_gradient

    if value>@color1value
      value = @color1value
    elsif value<@color3value
      value = @color3value
    end

    face.material = calculate_color(value)
  end

  def step_value(value)
    case value
      when @color3value..@color2value
        @color2value
      when @color2value..@color1value
        @color1value
      else
        value
    end
  end

  def calculate_color(value)
    case value
      when @color3value..@color2value
        s = (value - @color3value)/(@color2value - @color3value)
        return @cache1.get(s)
      when @color2value..@color1value
        s = (value - @color2value)/(@color1value - @color2value)
        return @cache2.get(s)
      else
        raise 'value is outside allowed range'
    end
  end

  def update_tile_colors
    faces = @irradiance_statistics.tile_groups.collect { |g| g.entities.select { |e| e.is_a? Sketchup::Face } }.reduce(:+)
    if faces
      progress = Progress.new(faces.length, 'Repainting tiles')
      faces.each do |face|
        recolor(face)
        progress.work
      end
      progress.finish
    end
  end

  def face_property(face, name)
    return face.get_attribute('solar_integration', name)
  end
end