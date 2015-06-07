require 'solar_integration/scale.rb'

# singleton to hold all rendered tiles, color them, sum up irradiance
class IrradianceStatistics < DhtmlDialog
  attr_accessor :tile_groups, :scale,
    :pointer_value, :max_irradiance, :total_irradiation, :tiless
  
  def initialize_values
    @skip_variables = ['@tiless']
    @tiless = []
    @scale = Scale.new(self)
    @max_irradiance = 10000
  end
  
  def add_tiles(tiles)
    @tiless.push tiles
  end
  
  def set_pointer_value(irradiance, relative_irradiance)
    if @scale.color_by_relative_value
      @pointer_value = relative_irradiance
    else
      @pointer_value = irradiance
    end
    puts @pointer_value
    update_dialog
  end
  
  def tiless
    @tiless.reject! {|t| t.group.deleted?}
    return @tiless
  end
  
  def max_irradiance
    @max_irradiance = tiless.collect{|t|t.max_irradiance}.max
    return @max_irradiance
  end
  
  def integration_finished
    @total_irradiation = tiless.collect{|t|t.total_irradiation}.reduce(:+)
    update_dialog
  end
end
