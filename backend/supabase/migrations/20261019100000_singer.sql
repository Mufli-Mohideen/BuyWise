-- Singer joins as the third retailer: its products are matched onto the Celltronics and Abans catalogue,
-- and its ~470 stores fill in the store map outside Colombo.
insert into public.retailers (id, name, website) values
  ('singer', 'Singer', 'singersl.com')
on conflict (id) do update set name = excluded.name, website = excluded.website;
