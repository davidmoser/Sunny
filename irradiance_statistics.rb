require 'solar_integration/scale.rb'
require 'solar_integration/tiles_observer.rb'
require 'sketchup.rb'

# singleton to hold all rendered tiles, color them, sum up irradiance
class IrradianceStatistics < DhtmlDialog
  attr_accessor :scale, :tile_groups,
                :pointer_value, :max_irradiance,
                :total_irradiation, :total_kwh, :kwp, :kwh_per_kwp

  def initialize
    @skip_variables = ['@tile_groups', '@visible_tile_groups', '@pointer_value']
    @pointer_value = nil
    super
  end

  def initialize_values
    @scale = Scale.new(self)
    @max_irradiance = 10000
    @tile_groups = find_tile_groups(Sketchup.active_model.entities)
    @tile_groups.each { |g| g.add_observer(TilesObserver.new) }
  end

  def add_tile_group(group)
    @tile_groups.push group
  end

  def set_pointer_value(irradiance, relative_irradiance)
    if @scale.color_by_relative_value
      @pointer_value = relative_irradiance
    else
      @pointer_value = irradiance
    end
    #puts @pointer_value
    update_dialog
  end

  def find_tile_groups(entities)
    groups = []
    entities.each do |e|
      if e.is_a? Sketchup::Group
        if e.attribute_dictionary('solar_integration')
          groups.push e
        else
          groups += find_tile_groups(e.entities)
        end
      end
    end
    return groups
  end

  def update_tile_groups
    @tile_groups.reject! { |g| g.deleted? }
    @visible_tile_groups = @tile_groups.select { |g| g.visible? }
  end

  def max_irradiance
    update_tile_groups
    @max_irradiance = tile_groups.collect { |g| get_group_property(g, 'max_irradiance') }.max
    return @max_irradiance
  end

  def update_values
    configuration = $solar_integration.configuration
    efficiency = Float(configuration.cell_efficiency) / 100
    losses = Float(100 - configuration.system_losses) / 100

    update_tile_groups
    if @visible_tile_groups.empty?
      @total_irradiation = 0
      @total_kwh = 0
      @area = 0
      @kwp = 0
      @kwh_per_kwp = 0
    else
      @total_irradiation = sum_group_properties('total_irradiation')
      @total_kwh = @total_irradiation * efficiency * losses
      @area = sum_group_properties('total_area')
      @kwp = @area * efficiency
      @kwh_per_kwp = @total_kwh / @kwp
    end

    update_dialog
  end

  def sum_group_properties(name)
    @visible_tile_groups.collect { |g| get_group_property(g, name) }.reduce(:+)
  end

  def get_group_property(group, name)
    group.get_attribute('solar_integration', name)
  end
end
