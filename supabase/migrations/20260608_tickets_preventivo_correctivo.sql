-- Campo procedimiento en planes_mantenimiento
ALTER TABLE planes_mantenimiento
  ADD COLUMN IF NOT EXISTS procedimiento text;