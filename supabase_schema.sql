-- Supabase SQL Schema for CARLOS — Sistema de Taller Privado

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- 1. PROFILES (Configuración por usuario)
create table if not exists public.profiles (
    id uuid references auth.users on delete cascade primary key,
    shop_name text,
    openai_api_key text,
    tax_rate numeric default 16,
    labor_rate numeric default 20,
    currency text default 'MXN',
    updated_at timestamptz default now()
);

-- Enable RLS for profiles
alter table public.profiles enable row level security;
create policy "Users can view their own profile" on public.profiles for select using (auth.uid() = id);
create policy "Users can update their own profile" on public.profiles for update using (auth.uid() = id);

-- 2. MATERIALES (Inventario)
create table if not exists public.materials (
    id uuid default uuid_generate_v4() primary key,
    user_id uuid references auth.users not null,
    nombre text not null,
    tipo text,
    espesor text,
    stock_m2 numeric default 0,
    stock_minimo_m2 numeric default 0,
    precio_venta_m2 numeric default 0,
    created_at timestamptz default now()
);

-- Enable RLS for materials
alter table public.materials enable row level security;
create policy "Users can manage their own materials" on public.materials 
    using (auth.uid() = user_id);

-- 3. MOVIMIENTOS (Caja)
create table if not exists public.movements (
    id uuid default uuid_generate_v4() primary key,
    user_id uuid references auth.users not null,
    tipo text check (tipo in ('entrada', 'salida')) not null,
    monto numeric default 0 not null,
    categoria text,
    descripcion text,
    fecha timestamptz default now()
);

-- Enable RLS for movements
alter table public.movements enable row level security;
create policy "Users can manage their own movements" on public.movements 
    using (auth.uid() = user_id);

-- 4. COTIZACIONES (Cabecera)
create table if not exists public.quotes (
    id uuid default uuid_generate_v4() primary key,
    user_id uuid references auth.users not null,
    cliente_nombre text not null,
    cliente_telefono text,
    descripcion_obra text,
    subtotal numeric default 0,
    labor numeric default 0,
    tax numeric default 0,
    total numeric default 0,
    estado text default 'borrador' check (estado in ('borrador', 'enviada')),
    notes_ia text,
    creada_en timestamptz default now()
);

-- Enable RLS for quotes
alter table public.quotes enable row level security;
create policy "Users can manage their own quotes" on public.quotes 
    using (auth.uid() = user_id);

-- 5. QUOTE_ITEMS (Detalle de cotización)
create table if not exists public.quote_items (
    id uuid default uuid_generate_v4() primary key,
    quote_id uuid references public.quotes on delete cascade not null,
    tipo text,
    espesor text,
    ancho numeric default 1,
    alto numeric default 1,
    cant numeric default 1,
    m2 numeric generated always as (ancho * alto * cant) stored,
    price numeric default 0,
    total numeric generated always as (ancho * alto * cant * price) stored
);

-- Enable RLS for quote_items
alter table public.quote_items enable row level security;
create policy "Users can manage items of their own quotes" on public.quote_items 
    using (
        exists (
            select 1 from public.quotes 
            where public.quotes.id = public.quote_items.quote_id 
            and public.quotes.user_id = auth.uid()
        )
    );

-- Trigger to update profiles.updated_at
create or replace function public.handle_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

create trigger set_updated_at
before update on public.profiles
for each row execute procedure public.handle_updated_at();
