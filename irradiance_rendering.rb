require 'sketchup.rb'
require 'solar_integration/progress.rb'
require 'solar_integration/grid.rb'
require 'solar_integration/spherical_hash_map.rb'
require 'solar_integration/shadow_caster.rb'
require 'solar_integration/sun_data.rb'
require 'solar_integration/irradiance_statistics.rb'
require 'solar_integration/sky_sections.rb'

class IrradianceRendering
  def initialize(face, sun_data)
    @grid = Grid.new(face)
    @data_collectors = $configuration.active_data_collectors.collect { |c| c.new(@grid) }
    @irradiances = calculate_irradiances(sun_data, @grid.normal)
    @sky_sections = SkySections.new(@irradiances, @data_collectors)
    @shadow_caster = ShadowCaster.new(@grid)
  end
  
  def calculate_irradiances(sun_data, normal)
    irradiances = Hash.new
    for state in sun_data.states
      vector = state.local_vector
      if vector%Z_AXIS > 0 and vector%normal > 0
        irradiances[state] = (normal % vector)
      end
    end
    return irradiances
  end
  
  def render()
    render_t = 0
    prepare_center_t = 0
    prepare_position_t = 0
    @with_shadow = 0
    @without_shadow = 0
    progress = Progress.new(@grid.number_of_subsquares, 'Integrating irradiances...')
    Sketchup.active_model.start_operation('Integrating irradiances', true)
    for square in @grid.squares
      t1 = Time.new
      @shadow_caster.prepare_center(square.center)
      t2 = Time.new
      for point in square.points
        t3 = Time.new
        prepare_point(point)
        t4 = Time.new
        render_shadows()
        t5 = Time.new
        progress.work
        prepare_position_t += t4-t3
        render_t += t5-t4
      end
      prepare_center_t += t2-t1
    end
    @data_collectors.each { |c| c.wrapup }
    Sketchup.active_model.commit_operation
    puts "prepare center #{prepare_center_t.round(2)}, "\
      "prepare position #{prepare_position_t.round(2)}, "\
      "render time #{render_t.round(2)}"
    puts "sections with shadow #{@with_shadow}, without shadow #{@without_shadow}"
  end
  
  def prepare_point(point)
    @data_collectors.each { |c| c.current_point=point }
    @shadow_caster.prepare_position(point)
  end
  
  def render_shadows()
    for sky_section in @sky_sections.sections
      if @shadow_caster.is_shadow_section? sky_section
        @with_shadow += 1
        for state in sky_section.sun_states
          irradiance = nil
          if !@shadow_caster.has_shadow? state.vector
            irradiance = @irradiances[state]
          end
          @data_collectors.each {|c| c.put(state, irradiance)}
        end
      else
        @without_shadow += 1
        @data_collectors.each {|c| c.put_section(sky_section)}
      end
    end
  end
end