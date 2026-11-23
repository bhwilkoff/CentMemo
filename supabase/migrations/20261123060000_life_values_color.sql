-- D14: a theme can keep a color the person chose. Null means the shared rule
-- (js/money/themes.js, apple/Core/Models/Themes.swift) picks one: a starter
-- theme's own color, else the first palette color no other theme holds.
alter table public.life_values add column color text
  check (color in ('clay','persimmon','ochre','olive','moss','sage','teal','sky','slate','iris','plum','rose','stone'));
comment on column public.life_values.color is 'D14: the color the person chose for this theme; null means the rule in js/money/themes.js and Themes.swift picks one.';
