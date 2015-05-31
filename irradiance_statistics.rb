
# singleton to hold all rendered tiles, color them, sum up irradiance
class IrradianceStatistics < DhtmlDialog
  attr_accessor :tile_groups, :color_by_relative_value, :color_bar,
    :color_bar_value, :max_irradiance, :total_irradiation
  
  def initialize_values
    @skip_variables = ['@tiless','@color_bar_value']
    @tiless = []
    @color_bar = ColorBar.new
    @color_by_relative_value = true
    @max_irradiance = 10000
  end
  
  def add_tiles(tiles)
    @tiless.push tiles
  end
  
  def update_tile_colors
    if active_tiless.length>0
      @max_irradiance = active_tiless.collect{|t|t.max_irradiance}.max
      
    end
    Sketchup.active_model.start_operation('Repainting tiles', true)
    active_tiless.each{|t|t.update_tile_colors}
    Sketchup.active_model.commit_operation
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
  
  def initialize
    @skip_variables = ['@color1', '@color2', '@color3']
    @color_gradient = false
    @color1 = Sketchup::Color.new(254,232,200)
    @color2 = Sketchup::Color.new(253,187,132)
    @color3 = Sketchup::Color.new(227,74,51)
    @color1value = 100
    @color2value = 90
    @color3value = 80
  end
  
  def recolor(tile)
    if @color_by_relative_value
      value = tile.relative_irradiance
    else
      value = 100 * tile.irradiance / @max_irradiance
    end
    
    if not @color_gradient
      value = step_value(value)
    end
    
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
      return @color2.blend(@color3, s)
    when @color2value..@color1value
      s = (value - @color2value)/(@color1value - @color2value)
      return @color1.blend(@color2, s)
    else
      raise 'value is outside allowed range'
    end
  end
  
  def ==(o)
    o.class == self.class && o.state == state
  end
  
  def state
    [@color_gradient, @color1value, @color2value, @color3value, @color1, @color2, @color3]
  end

end