require 'solar_integration/scale.rb'

# singleton to hold all rendered tiles, color them, sum up irradiance
class IrradianceStatistics < DhtmlDialog
  attr_accessor :tile_groups, :scale,
    :pointer_value, :max_irradiance, :tiless,
    :total_irradiation, :total_kwh, :kwp, :kwh_per_kwp
  
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
    efficiency = Float($configuration.cell_efficiency) / 100
    losses = Float(100 - $configuration.system_losses) / 100
    
    @total_irradiation = tiless.collect{|t|t.total_irradiation}.reduce(:+)
    @total_kwh = @total_irradiation * efficiency * losses
    @area = tiless.collect{|t|t.grid.total_area}.reduce(:+)
    @kwp = @area * efficiency
    @kwh_per_kwp = @total_kwh / @kwp
    
    update_dialog
  end
end
