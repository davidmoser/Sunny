
# singleton to hold all rendered tiles, color them, sum up irradiance
class IrradianceStatistics < DhtmlDialog
  attr_accessor :tile_groups, :color_by_relative_value, :color_bar,
    :color_bar_value, :max_irradiance, :total_irradiation
  
  def initialize_values
    @skip_variables = ['@tiless','@color_bar_value']
    @tiless = []
    @color_bar = ColorBar.new(self)
    @color_by_relative_value = true
    @max_irradiance = 10000
  end
  
  def add_tiles(tiles)
    @tiless.push tiles
  end
  
  def update_tile_colors
    if active_tiless.length>0
      @max_irradiance = active_tiless.collect{|t|t.max_irradiance}.max
      Sketchup.active_model.start_operation('Repainting tiles', true)
      active_tiless.each{|t|t.update_tile_colors}
      Sketchup.active_model.commit_operation
    end
  end
  
  def color_by_relative_value=(color_by_relative_value)
    if not @color_by_relative_value == color_by_relative_value
      @color_by_relative_value = color_by_relative_value
      set_color_bar_value(nil, nil)
      update_tile_colors
    end
  end
  
  def set_color_bar_value(irradiance, relative_irradiance)
    if @color_by_relative_value
      @color_bar_value = relative_irradiance
    else
      @color_bar_value = irradiance
    end
    puts @color_bar_value
    update_dialog
  end
  
  def active_tiless
    @tiless.reject! {|t| t.group.deleted?}
    return @tiless
  end
  
  def integration_finished
    @total_irradiation = active_tiless.collect{|t|t.total_irradiation}.reduce(:+)
    update_dialog
  end
end

class ColorBar < JsonSerialization
  
  def initialize(irradiance_statistics)
    @color_gradient = false
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
      @irradiance_statistics.set_color_bar_value(nil, nil)
      @irradiance_statistics.update_tile_colors
    end
  end
  
  def recolor(tile)
    if @irradiance_statistics.color_by_relative_value
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
      return Sketchup::Color.new(@color2).blend(@color3, s)
    when @color2value..@color1value
      s = (value - @color2value)/(@color1value - @color2value)
      return Sketchup::Color.new(@color1).blend(@color2, s)
    else
      raise 'value is outside allowed range'
    end
  end

end