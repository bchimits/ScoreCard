import Foundation

struct SupabaseConfig {
    // Create a free Supabase project, then paste these values from Project Settings > API.
    // Leave either value empty to keep using the local in-memory test store.
    static let projectURL = "https://ksrcquybmluyzmtzqkvu.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzcmNxdXlibWx1eXptdHpxa3Z1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1NzA4NjYsImV4cCI6MjA5NzE0Njg2Nn0.Dg6KgnEcphJbGiNtuS5Gau_PZpp2NWHRNtAqE1ipP9Q"

    static var isConfigured: Bool {
        !projectURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/*
Supabase SQL schema for ScoreCard:

create table public.rounds (
    id text primary key,
    join_code text not null unique,
    name text not null,
    format text not null,
    holes integer not null,
    course_name text not null,
    course_rating double precision not null,
    slope_rating integer not null,
    par integer not null,
    course_holes jsonb,
    created_at timestamptz not null,
    is_finished boolean not null default false
);

create table public.players (
    id text primary key,
    round_id text not null references public.rounds(id) on delete cascade,
    name text not null,
    handicap_index double precision not null,
    team_number integer,
    tee_color text not null,
    device_id text not null,
    course_handicap integer not null
);

create table public.scores (
    id text primary key,
    round_id text not null references public.rounds(id) on delete cascade,
    player_id text not null references public.players(id) on delete cascade,
    hole_number integer not null,
    gross_strokes integer not null
);

create index players_round_id_idx on public.players(round_id);
create index scores_round_id_idx on public.scores(round_id);

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.rounds to anon, authenticated;
grant select, insert, update, delete on public.players to anon, authenticated;
grant select, insert, update, delete on public.scores to anon, authenticated;

For quick testing, disable Row Level Security on these three tables.
Before real beta/public use, turn RLS back on and add proper policies.
*/
