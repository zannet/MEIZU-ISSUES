json.array! @events do |json, event|
  json.text event.text
  json.position event.position  
  json.startTime event.start_at.strftime("%Y-%m-%d")
  json.endTime  event.end_at.strftime("%Y-%m-%d") 
  json.conflictStart event.conflict_start.try(:strftime, "%Y-%m-%d")
  json.conflictEnd event.conflict_end.try(:strftime, "%Y-%m-%d")
  json.eventableType event.eventable_type
  json.eventableId  event.eventable_id  
  json.color event.color  
  json.id event.id
end  
