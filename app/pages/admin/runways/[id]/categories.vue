<script setup lang="ts">
import type { AdminCategory } from '~/composables/useAdminRunway'
import type { Enums } from '~/types/database.types'

type CategoryKind = Enums<'category_kind'>

const supabase = useSupabaseClient()
const { runway, categories, refresh } = useAdminRunway()
const { listCategoryFiles, removeFiles } = useParticipantFiles()

// --- Edit title / intro, delete ----------------------------------------------
const categoryDrafts = reactive<Record<string, { title: string, intro: string, kind: CategoryKind }>>({})
watch(categories, (list) => {
  for (const category of list) {
    categoryDrafts[category.id] ??= { title: category.title, intro: category.intro_text ?? '', kind: category.kind }
  }
}, { immediate: true })

const categorySavingId = ref<string | null>(null)
const snackbar = useSnackbar()

const categoryChanged = (category: AdminCategory): boolean => {
  const draft = categoryDrafts[category.id]
  return !!draft && (draft.title.trim() !== category.title || (draft.intro.trim() || null) !== category.intro_text || draft.kind !== category.kind)
}

// A runway has either one group category on its own or individual categories only
const hasGroupCategory = computed(() => categories.value.some(category => category.kind === 'group'))
const GROUP_NEEDS_EMPTY_RUNWAY = 'Una categoría grupal no puede convivir con otras categorías: elimina primero las categorías individuales.'

/** Whether the draft makes this category grupal while the runway has other categories */
const groupBlocked = (category: AdminCategory): boolean =>
  categoryDrafts[category.id]?.kind === 'group' && category.kind !== 'group' && categories.value.length > 1

async function saveCategory(category: AdminCategory): Promise<void> {
  const draft = categoryDrafts[category.id]
  if (!draft || !categoryChanged(category) || !draft.title.trim() || categorySavingId.value || groupBlocked(category)) return

  categorySavingId.value = category.id
  try {
    const { error } = await supabase
      .from('categories')
      .update({ title: draft.title.trim(), intro_text: draft.intro.trim() || null, kind: draft.kind })
      .eq('id', category.id)
    if (error) throw error
    await refresh()
    snackbar.success('Categoría guardada.')
  }
  catch (error) {
    snackbar.error(toErrorMessage(error))
  }
  finally {
    categorySavingId.value = null
  }
}

async function deleteCategory(category: AdminCategory): Promise<void> {
  if (categorySavingId.value) return
  if (!window.confirm(`¿Eliminar la categoría «${category.title}»? También se borrarán sus looks.`)) return

  categorySavingId.value = category.id
  try {
    // The looks cascade with the row; list their files first so they can be removed from Storage
    const files = await listCategoryFiles(category.id)
    const { error } = await supabase.from('categories').delete().eq('id', category.id)
    if (error) throw error
    await removeFiles(files)
    await refresh()
  }
  catch (error) {
    snackbar.error(toErrorMessage(error))
  }
  finally {
    categorySavingId.value = null
  }
}

// --- New category --------------------------------------------------------------
const newCategoryOpen = ref(false)
const newTitle = ref('')
const newIntro = ref('')
const newKind = ref<CategoryKind>('individual')
const newCategorySaving = ref(false)
const newGroupBlocked = computed(() => newKind.value === 'group' && categories.value.length > 0)

function openNewCategory(): void {
  newTitle.value = ''
  newIntro.value = ''
  newKind.value = 'individual'
  newCategoryOpen.value = true
}

async function createCategory(): Promise<void> {
  if (!newTitle.value.trim() || newCategorySaving.value || newGroupBlocked.value) return

  newCategorySaving.value = true
  try {
    const { error } = await supabase
      .from('categories')
      .insert({ runway_id: runway.value.id, title: newTitle.value.trim(), intro_text: newIntro.value.trim() || null, kind: newKind.value })
    if (error) throw error
    newCategoryOpen.value = false
    await refresh()
  }
  catch (error) {
    snackbar.error(toErrorMessage(error))
  }
  finally {
    newCategorySaving.value = false
  }
}
</script>

<template>
  <section class="section" aria-labelledby="categories-title">
    <div class="section-header">
      <h2 id="categories-title">
        Categorías
      </h2>
      <button type="button" class="btn btn--primary" :disabled="hasGroupCategory" @click="openNewCategory">
        + Nueva categoría
      </button>
    </div>

    <p v-if="hasGroupCategory" class="hint" role="status">
      Esta pasarela ya tiene una categoría grupal, que va sola: para añadir otra categoría, elimina primero la grupal.
    </p>

    <p v-if="!categories.length" class="empty">
      Añade al menos una categoría para poder subir los looks.
    </p>

    <template v-for="category in categories" :key="category.id">
    <form
      class="card form"
      @submit.prevent="saveCategory(category)"
    >
      <div class="field">
        <label :for="`category-title-${category.id}`" class="field__label">Título</label>
        <input
          :id="`category-title-${category.id}`"
          v-model="categoryDrafts[category.id]!.title"
          class="field__input"
          type="text"
          maxlength="100"
          required
        >
      </div>
      <div class="field">
        <label :for="`category-intro-${category.id}`" class="field__label">Introducción</label>
        <textarea
          :id="`category-intro-${category.id}`"
          v-model="categoryDrafts[category.id]!.intro"
          class="field__input"
          rows="3"
        />
      </div>
      <div class="field">
        <label :for="`category-kind-${category.id}`" class="field__label">Tipo</label>
        <select :id="`category-kind-${category.id}`" v-model="categoryDrafts[category.id]!.kind" class="field__input">
          <option value="individual">
            Individual
          </option>
          <option value="group">
            Grupal (dos grupos)
          </option>
        </select>
      </div>
      <p v-if="groupBlocked(category)" class="form-error" role="alert">
        {{ GROUP_NEEDS_EMPTY_RUNWAY }}
      </p>
      <div class="form-actions">
        <button
          v-if="canEditLooks(runway.status)"
          type="button"
          class="btn btn--ghost"
          :disabled="categorySavingId !== null"
          @click="deleteCategory(category)"
        >
          Eliminar
        </button>
        <AdminCategoryGroups v-if="category.kind === 'group'" :category="category" />
        <AdminCategorySubcategories v-else-if="category.kind === 'individual'" :category="category" />
        <button type="submit" class="btn btn--primary" :disabled="!categoryChanged(category) || categorySavingId !== null || groupBlocked(category)">
          {{ categorySavingId === category.id ? 'Guardando…' : 'Guardar' }}
        </button>
      </div>
    </form>
    </template>
  </section>

  <AppModal :open="newCategoryOpen" title="Nueva categoría" @close="newCategoryOpen = false">
    <form class="form" @submit.prevent="createCategory">
      <div class="field">
        <label for="new-category-title" class="field__label">Título</label>
        <input
          id="new-category-title"
          v-model="newTitle"
          class="field__input"
          type="text"
          maxlength="100"
          required
          placeholder="Ej. Alta costura espacial"
        >
      </div>
      <div class="field">
        <label for="new-category-intro" class="field__label">Introducción</label>
        <textarea
          id="new-category-intro"
          v-model="newIntro"
          class="field__input"
          rows="3"
          placeholder="Describe el tema (opcional)"
        />
      </div>
      <div class="field">
        <label for="new-category-kind" class="field__label">Tipo</label>
        <select id="new-category-kind" v-model="newKind" class="field__input">
          <option value="individual">
            Individual
          </option>
          <option value="group">
            Grupal (dos grupos)
          </option>
        </select>
      </div>
      <p v-if="newGroupBlocked" class="form-error" role="alert">
        {{ GROUP_NEEDS_EMPTY_RUNWAY }}
      </p>
      <div class="form-actions">
        <button type="button" class="btn btn--ghost" @click="newCategoryOpen = false">
          Cancelar
        </button>
        <button type="submit" class="btn btn--primary" :disabled="!newTitle.trim() || newCategorySaving || newGroupBlocked">
          {{ newCategorySaving ? 'Creando…' : 'Crear categoría' }}
        </button>
      </div>
    </form>
  </AppModal>
</template>
