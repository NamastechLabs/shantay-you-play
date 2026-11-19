<script setup lang="ts">
interface DraftItem {
  /** Missing until the sub-category is stored */
  id?: string
  name: string
}

const props = defineProps<{
  category: { id: string, title: string }
}>()

const supabase = useSupabaseClient()
const { subcategories, queens, loading, error: loadError, queenOf, init, assign, free } = useCategorySubcategories(() => props.category.id)

const open = ref(false)
const saving = ref(false)
const error = ref('')

// The draft being edited: nothing is stored until "Guardar"
const draft = ref<DraftItem[]>([])

const names = computed(() => draft.value.map(item => item.name.trim()))
const namesValid = computed(() => names.value.every(name => name.length > 0) && new Set(names.value.map(name => name.toLowerCase())).size === names.value.length)
/** Optional, but if there are any, every queen needs one */
const enough = computed(() => draft.value.length === 0 || draft.value.length >= queens.value.length)
const changed = computed(() =>
  draft.value.length !== subcategories.value.length
  || draft.value.some((item, index) => item.id !== subcategories.value[index]?.id || item.name.trim() !== subcategories.value[index]?.name),
)

function resetDraft(): void {
  draft.value = subcategories.value.map(subcategory => ({ id: subcategory.id, name: subcategory.name }))
}

async function openPanel(): Promise<void> {
  open.value = true
  error.value = ''
  await init()
  resetDraft()
}

function addItem(): void {
  draft.value.push({ name: '' })
}

function removeItem(index: number): void {
  draft.value.splice(index, 1)
}

async function save(): Promise<void> {
  if (saving.value || loading.value || !namesValid.value || !enough.value || !changed.value) return
  const stored = subcategories.value
  const hasPick = (id?: string): boolean => !!id && !!queenOf(id)
  const removing = stored.filter(subcategory => !draft.value.some(item => item.id === subcategory.id))
  const withPick = removing.filter(subcategory => hasPick(subcategory.id))
  if (withPick.length && !window.confirm(`Se borrarán ${withPick.length} subcategoría(s) ya elegidas por una reina. ¿Continuar?`)) return

  saving.value = true
  error.value = ''
  try {
    // 1. Removed ones first (their picks cascade)
    if (removing.length) {
      const removed = await supabase.from('category_subcategories').delete().in('id', removing.map(subcategory => subcategory.id))
      if (removed.error) throw removed.error
    }

    // 2. Renamed or moved ones, and the new ones
    for (const [index, item] of draft.value.entries()) {
      const name = item.name.trim()
      const position = index + 1
      if (item.id) {
        const current = stored.find(subcategory => subcategory.id === item.id)
        if (current && current.name === name && current.position === position) continue
        const updated = await supabase.from('category_subcategories').update({ name, position }).eq('id', item.id)
        if (updated.error) throw updated.error
      }
      else {
        const created = await supabase.from('category_subcategories').insert({ category_id: props.category.id, name, position })
        if (created.error) throw created.error
      }
    }

    await init()
    resetDraft()
    open.value = false
  }
  catch (caught) {
    const message = toErrorMessage(caught)
    // Show what is really stored, so a partial save is not hidden
    await init()
    resetDraft()
    error.value = message
  }
  finally {
    saving.value = false
  }
}

// --- Assign / free a pick (acts right away, independent of the draft) -------------
const assigning = ref<string | null>(null)

async function assignTo(participantId: string, subcategoryId: string): Promise<void> {
  if (!subcategoryId || assigning.value) return
  assigning.value = participantId
  error.value = ''
  try {
    await assign(subcategoryId, participantId)
  }
  catch (caught) {
    error.value = toErrorMessage(caught)
  }
  finally {
    assigning.value = null
  }
}

async function freeFrom(participantId: string): Promise<void> {
  if (assigning.value) return
  assigning.value = participantId
  error.value = ''
  try {
    await free(participantId)
  }
  catch (caught) {
    error.value = toErrorMessage(caught)
  }
  finally {
    assigning.value = null
  }
}

const nameOf = (subcategoryId: string | null): string => subcategories.value.find(subcategory => subcategory.id === subcategoryId)?.name ?? ''
</script>

<template>
  <button type="button" class="btn btn--secondary" @click="openPanel">
    Subcategorías
  </button>

  <!-- Teleported: the panel must not live inside the category <form> -->
  <Teleport to="body">
    <AppDrawer :open="open" :title="`Subcategorías · ${category.title}`" @close="open = false">
      <p v-if="loading" class="hint" role="status">
        Cargando…
      </p>

      <template v-else>
        <p class="hint">
          Opcional. Las reinas las eligen en el Werk Room, por orden de la clasificación de la semana anterior. Si añades alguna, debe haber al menos una por reina ({{ queens.length }}).
        </p>

        <fieldset class="subcats">
          <legend class="field__label">
            Subcategorías
          </legend>
          <p v-if="!draft.length" class="hint">
            Aún no hay subcategorías.
          </p>
          <div v-for="(item, index) in draft" :key="item.id ?? `new-${index}`" class="subcats__row">
            <input
              v-model="item.name"
              class="field__input"
              type="text"
              maxlength="80"
              required
              placeholder="Nombre de la subcategoría"
              :aria-label="`Subcategoría ${index + 1}`"
            >
            <button type="button" class="btn btn--ghost btn--danger" :aria-label="`Quitar la subcategoría ${index + 1}`" @click="removeItem(index)">
              <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6M10 11v6M14 11v6" />
              </svg>
            </button>
          </div>
          <button type="button" class="btn btn--secondary" @click="addItem">
            + Añadir subcategoría
          </button>
          <p v-if="!enough" class="form-error" role="alert">
            Faltan subcategorías: hay {{ queens.length }} reinas y {{ draft.length }} subcategorías.
          </p>
          <p v-else-if="!namesValid" class="form-error" role="alert">
            Cada subcategoría necesita un nombre distinto.
          </p>
        </fieldset>

        <fieldset v-if="subcategories.length && queens.length" class="subcats">
          <legend class="field__label">
            Elección de las reinas
          </legend>
          <p class="hint">
            Puedes asignar o liberar una subcategoría por cualquier reina. Se guarda al momento.
          </p>
          <div v-for="queen in queens" :key="queen.id" class="subcats__queen">
            <span class="subcats__who">{{ queen.turn }}. {{ queen.name }}</span>
            <select
              class="field__input"
              :aria-label="`Subcategoría de ${queen.name}`"
              :value="queen.subcategoryId ?? ''"
              :disabled="assigning !== null"
              @change="assignTo(queen.id, ($event.target as HTMLSelectElement).value)"
            >
              <option value="" disabled>
                Sin elegir
              </option>
              <option
                v-for="subcategory in subcategories"
                :key="subcategory.id"
                :value="subcategory.id"
                :disabled="!!queenOf(subcategory.id) && queenOf(subcategory.id)!.id !== queen.id"
              >
                {{ subcategory.name }}{{ queenOf(subcategory.id) && queenOf(subcategory.id)!.id !== queen.id ? ` (${queenOf(subcategory.id)!.name})` : '' }}
              </option>
            </select>
            <button
              type="button"
              class="btn btn--ghost"
              :disabled="!queen.subcategoryId || assigning !== null"
              :title="queen.subcategoryId ? `Liberar «${nameOf(queen.subcategoryId)}»` : ''"
              @click="freeFrom(queen.id)"
            >
              Liberar
            </button>
          </div>
        </fieldset>

        <p v-if="error || loadError" class="form-error" role="alert">
          {{ error || loadError }}
        </p>
      </template>

      <template #footer>
        <button type="button" class="btn btn--ghost" :disabled="saving" @click="open = false">
          Cerrar
        </button>
        <button type="button" class="btn btn--primary" :disabled="loading || saving || !namesValid || !enough || !changed" @click="save">
          {{ saving ? 'Guardando…' : 'Guardar subcategorías' }}
        </button>
      </template>
    </AppDrawer>
  </Teleport>
</template>

<style scoped lang="scss">
.subcats {
  display: grid;
  gap: var(--space-3);
  padding: var(--space-3);
  margin: 0;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
}

.subcats__row,
.subcats__queen {
  display: flex;
  gap: var(--space-2);
  align-items: center;

  select,
  input {
    flex: 1;
    min-width: 0;
  }

  .btn {
    flex-shrink: 0;
  }
}

.subcats__who {
  flex: 0 1 8rem;
  min-width: 0;
  overflow-wrap: anywhere;
}
</style>
