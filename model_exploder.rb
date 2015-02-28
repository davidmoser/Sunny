
def explode_model(model)
  return explode_entities(model.entities)
end

def explode_entities(entities)
  return entities.collect{|e| explode_entity(e)}.reduce(:+)
end

def explode_entity(entity)
  case entity
  when Sketchup::Group
    return explode_entities(entity.entities)
  when Sketchup::ComponentInstance
    return explode_entities(entity.definition.entities)
  when Sketchup::Face
    return explode_face(entity)
  else
    return []
  end
end

def explode_face(face)
  mesh = face.mesh(0)
  return (1..mesh.count_polygons).collect {|i| mesh.polygon_points_at(i)}
end