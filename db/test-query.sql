SELECT address, connect, disconnect 
  FROM aep, connection
  WHERE id = aep_id 
    AND agent_id = (SELECT id FROM agent LIMIT 1)
  ORDER BY connect DESC LIMIT 1;
