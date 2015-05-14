
module PolygonCollector
  def collect_model_polygons(model)
    return collect_from_entities(model.entities, Geom::Transformation.new)
  end

  def collect_from_entities(entities, transformation)
    polygons = []
    entities.each do |e|
      collect_from_entity(e).each do |polygon|
        polygons.push polygon.collect{|p|p.transform(transformation)}
      end
    end
    return polygons
  end

  def collect_from_entity(entity)
    return [] if entity.hidden?
    case entity
    when Sketchup::Group
      return collect_from_entities(entity.entities, entity.transformation)
    when Sketchup::ComponentInstance
      return collect_from_entities(entity.definition.entities, entity.transformation)
    when Sketchup::Face
      return collect_from_face(entity)
    else
      return []
    end
  end

  def collect_from_face(face)
    mesh = face.mesh(0)
    return (1..mesh.count_polygons).collect {|i| mesh.polygon_points_at(i)}
  end
end