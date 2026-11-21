-- The connector must be able to total spending without FinanceKit rows
-- (FinanceKit APIs Addendum 3.2; see supabase/functions/mcp/index.ts).
drop function public.spending_summary(date, date, text);
create function public.spending_summary(from_date date, to_date date, group_by text, exclude_financekit boolean default false)
returns table (label text, spent_minor bigint, received_minor bigint, count bigint)
language sql stable security invoker set search_path = '' as $$
  select
    case group_by
      when 'month' then to_char(t.txn_date, 'YYYY-MM')
      when 'category' then coalesce(nullif(t.category, ''), 'Uncategorized')
      when 'value' then coalesce(v.name, 'No value named')
    end as label,
    coalesce(sum(-t.amount_minor) filter (where t.amount_minor < 0), 0)::bigint,
    coalesce(sum(t.amount_minor) filter (where t.amount_minor > 0), 0)::bigint,
    count(*)
  from public.transactions t
  left join public.memo_values mv on group_by = 'value' and mv.transaction_id = t.id
  left join public.life_values v on v.id = mv.value_id
  where t.txn_date between from_date and to_date
    and t.status <> 'rejected'
    and group_by in ('month', 'category', 'value')
    and (not exclude_financekit or t.source <> 'financekit')
  group by 1
  order by 2 desc;
$$;
grant execute on function public.spending_summary(date, date, text, boolean) to authenticated;
