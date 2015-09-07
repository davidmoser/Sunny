
class DataCollector
  # during shadow calculation the current point for which all sun states
  # are rendered, i.e. shadow is checked, is set to this variable
  attr_writer :current_point
  
  def initialize(grid, sun_data)
  end
  
  # for performance reasons the sky is split in sections
  # before rendering shadows all sections are rendered with all sun states
  # i.e. as if there was no shadow at all, that accumulated data for a section
  # can then be used when during shadow calculation it is evident that there's
  # no shadow cast for a particular section, in which case put_section is called
  def prepare_section(sun_state, irradiance, section)
  end
  
  # all sections have been rendered
  def section_preparation_finished
  end

  # called during shadow rendering.
  # sun shines with strength irradiance on @current_point
  # if @current_point is in the shadow then irradiance=nil.
  def put(sun_state, irradiance)
  end
  
  # if for @current_point there aren't any shadow casting polygons
  # from a certain sky section, then this method is called instead of put
  def put_section(section)
  end
  
  def wrapup
  end
end
