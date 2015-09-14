
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
    @color1 = [255,255,0]
    @color2 = [255,0,0]
    @color3 = [0,0,255]
    @color1value = 100
    @color2value = 80
    @color3value = 60
    # volatile
    @current_hash = ''
    @irradiance_statistics = irradiance_statistics
    @skip_variables = ['@current_hash', '@irradiance_statistics']
  end
  
  def update_from_hash(hash)
    unless @current_hash==hash
      @current_hash = hash
      super(hash)
      @irradiance_statistics.set_pointer_value(nil, nil)
      update_tile_colors
    end
  end
  
  def recolor(tile)
    if @color_by_relative_value
      value = tile.relative_irradiance
    else
      value = 100 * tile.irradiance / @irradiance_statistics.max_irradiance
    end
    
    value = step_value(value) if not @color_gradient
    
    if value>@color1value
      value = @color1value
    elsif value<@color3value
      value = @color3value
    end
    
    tile.face.material = calculate_color(value)
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
    @cache1 = ColorCache.new(@color2, @color3)
    @cache2 = ColorCache.new(@color1, @color2)
    tiless = @irradiance_statistics.tiless
    if tiless.length>0
      Sketchup.active_model.start_operation('Repainting tiles', true)
      tiless.each{|t|t.update_tile_colors}
      Sketchup.active_model.commit_operation
    end
  end

end