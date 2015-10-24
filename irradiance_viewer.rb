require 'sketchup.rb'

class IrradianceViewer
  def onMouseMove(flags, x, y, view)
    ph = view.pick_helper
    ph.do_pick(x, y)
    index = ph.all_picked.index { |e| e.is_a?(Sketchup::Group) && e.name == 'Solar Integration' }
    if index
      entity = ph.leaf_at(index)
      irradiance = entity.get_attribute 'solar_integration', 'irradiance'
      if irradiance and irradiance!=@current_irradiance
        @current_irradiance = irradiance
        relative_irradiance = entity.get_attribute 'solar_integration', 'relative_irradiance'
        view.tooltip = "irradiance: %.0f kWh/m^2/y, relative: %.1f" % [irradiance, relative_irradiance]
        $solar_integration.statistics.set_pointer_value(irradiance, relative_irradiance)
      end
    else
      view.tooltip = ''
    end
  end
end


