-- 伴日 資料庫設定
-- 使用方式：Supabase 後台 → SQL Editor → New query → 整份貼上 → Run
-- 可以重複執行，不會清掉既有資料。

-- ============ 資料表 ============

-- 一對情侶（兩個帳號共用一個空間）
create table if not exists public.couples (
  id uuid primary key default gen_random_uuid(),
  code text not null unique default upper(substr(md5(gen_random_uuid()::text), 1, 6)),  -- 邀請碼
  created_at timestamptz not null default now()
);

-- 帳號屬於哪一對（一個帳號只能在一對裡）
create table if not exists public.members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  couple_id uuid not null references public.couples(id) on delete cascade,
  joined_at timestamptz not null default now()
);
create index if not exists members_couple on public.members (couple_id);

-- 所有紀錄：飲食、花費、運動（logs）、獎品（rewards）、兌換（redeems）、共用設定（meta）
-- 刪除時只標記 deleted，另一支手機同步時才知道要移除
create table if not exists public.docs (
  couple_id uuid not null references public.couples(id) on delete cascade,
  col text not null check (col in ('logs', 'rewards', 'redeems', 'meta')),
  id text not null,
  data jsonb not null default '{}'::jsonb,
  deleted boolean not null default false,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  primary key (couple_id, col, id)
);
create index if not exists docs_sync on public.docs (couple_id, updated_at);

-- 每個人自己的偏好（例如上次用的付款方式），另一半看不到
create table if not exists public.prefs (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- ============ 自動更新時間 ============

create or replace function public.banri_touch() returns trigger
language plpgsql as $$
begin
  new.updated_at = clock_timestamp();
  if tg_table_name = 'docs' then new.updated_by = auth.uid(); end if;
  return new;
end $$;

drop trigger if exists docs_touch on public.docs;
create trigger docs_touch before insert or update on public.docs
  for each row execute function public.banri_touch();
drop trigger if exists prefs_touch on public.prefs;
create trigger prefs_touch before insert or update on public.prefs
  for each row execute function public.banri_touch();

-- ============ 權限 ============

-- 目前登入的人屬於哪一對
create or replace function public.my_couple() returns uuid
language sql stable security definer set search_path = public as $$
  select couple_id from public.members where user_id = auth.uid()
$$;

alter table public.couples enable row level security;
alter table public.members enable row level security;
alter table public.docs enable row level security;
alter table public.prefs enable row level security;

drop policy if exists "看自己這一對" on public.couples;
create policy "看自己這一對" on public.couples for select to authenticated
  using (id = public.my_couple());

drop policy if exists "看自己這一對的成員" on public.members;
create policy "看自己這一對的成員" on public.members for select to authenticated
  using (couple_id = public.my_couple());

drop policy if exists "只碰自己這一對的紀錄" on public.docs;
create policy "只碰自己這一對的紀錄" on public.docs for all to authenticated
  using (couple_id = public.my_couple())
  with check (couple_id = public.my_couple());

drop policy if exists "只碰自己的偏好" on public.prefs;
create policy "只碰自己的偏好" on public.prefs for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- couples、members 只能透過下面兩個函式建立或修改
revoke insert, update, delete on public.couples from authenticated, anon;
revoke insert, update, delete on public.members from authenticated, anon;

-- ============ 配對 ============

-- 取得自己的空間；第一次登入時自動建立
create or replace function public.my_space() returns json
language plpgsql security definer set search_path = public as $$
declare cid uuid;
begin
  if auth.uid() is null then raise exception '請先登入'; end if;
  select couple_id into cid from members where user_id = auth.uid();
  if cid is null then
    insert into couples default values returning id into cid;
    insert into members (user_id, couple_id) values (auth.uid(), cid);
  end if;
  return json_build_object(
    'couple_id', cid,
    'code', (select code from couples where id = cid),
    'members', (select coalesce(json_agg(user_id order by joined_at), '[]'::json) from members where couple_id = cid)
  );
end $$;

-- 輸入另一半的邀請碼，加入對方的空間；自己配對前記的紀錄會一起帶過去
create or replace function public.join_couple(p_code text) returns json
language plpgsql security definer set search_path = public as $$
declare target uuid; mine uuid;
begin
  if auth.uid() is null then raise exception '請先登入'; end if;
  select id into target from couples where code = upper(trim(p_code));
  if target is null then raise exception '找不到這組邀請碼，請再確認一次'; end if;
  select couple_id into mine from members where user_id = auth.uid();
  if mine = target then return public.my_space(); end if;
  if (select count(*) from members where couple_id = target) >= 2 then
    raise exception '這組邀請碼已經有兩個人了';
  end if;
  if mine is not null and (select count(*) from members where couple_id = mine) > 1 then
    raise exception '你已經和另一半配對了';
  end if;
  if mine is not null then
    update docs set couple_id = target where couple_id = mine and col <> 'meta';
    delete from members where user_id = auth.uid();
    delete from couples where id = mine;
  end if;
  insert into members (user_id, couple_id) values (auth.uid(), target);
  return public.my_space();
end $$;

revoke execute on function public.my_space() from public, anon;
revoke execute on function public.join_couple(text) from public, anon;
revoke execute on function public.my_couple() from public, anon;
grant execute on function public.my_couple() to authenticated;
grant execute on function public.my_space() to authenticated;
grant execute on function public.join_couple(text) to authenticated;
