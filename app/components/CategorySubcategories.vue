<script setup lang="ts">
import type { Subcategory } from '~/composables/useCategorySubcategories'

const props = defineProps<{
  category: { id: string, title: string }
  /** The category title is shown when the runway has several categories */
  showTitle?: boolean
}>()

/** Tells the page whether the signed-in queen still has to pick a sub-category (the page hides the rest of the week card until she does) */
const emit = defineEmits<{ pending: [categoryId: string, pending: boolean] }>()

const { participant } = useCurrentParticipant()
const { subcategories, queens, loading, error: loadError, nextQueen, queenOf, init, pick } = useCategorySubcategories(() => props.category.id, { realtime: true })

onMounted(() => void init())

const me = computed(() => queens.value.find(queen => queen.id === participant.value?.id) ?? null)
const myTurn = computed(() => !!me.value && nextQueen.value?.id === me.value.id)
const mySubcategory = computed(() => subcategories.value.find(subcategory => subcategory.id === me.value?.subcategoryId) ?? null)
/** Queens that pick before me and have not picked yet */
const waitingBefore = computed(() => (me.value ? queens.value.filter(queen => queen.turn < me.value!.turn && !queen.subcategoryId) : []))

const pending = computed(() => !!me.value && subcategories.value.length > 0 && !me.value.subcategoryId)
watch(pending, value => emit('pending', props.category.id, value), { immediate: true })
onBeforeUnmount(() => emit('pending', props.category.id, false))

// --- Picking: tap a free row, confirm in a sheet ---------------------------------------
const selected = ref<Subcategory | null>(null)
const picking = ref(false)
const pickError = ref('')
/** Shown right after picking */
const justPicked = ref(false)

async function confirmPick(): Promise<void> {
  if (!selected.value || picking.value) return
  picking.value = true
  pickError.value = ''
  try {
    await pick(selected.value.id)
    justPicked.value = true
    selected.value = null
  }
  catch (caught) {
    pickError.value = toErrorMessage(caught)
    selected.value = null
  }
  finally {
    picking.value = false
  }
}

const initial = (name: string): string => name.charAt(0).toUpperCase()
</script>

<template>
  <section v-if="subcategories.length" :id="`subcategorias-${category.id}`" class="subcats card" :aria-labelledby="`subcats-${category.id}`">
    <h2 :id="`subcats-${category.id}`" class="subcats__title">
      Subcategorías<template v-if="showTitle"> · {{ category.title }}</template>
    </h2>

    <!-- Status: the one thing a queen needs to know -->
    <p v-if="mySubcategory" class="subcats__status" role="status">
      <template v-if="justPicked">
        ¡Hecho! Tu subcategoría es
      </template>
      <template v-else>
        Tu subcategoría:
      </template>
      <strong>{{ mySubcategory.name }}</strong>
    </p>
    <p v-else-if="myTurn" class="subcats__status subcats__status--turn" role="status">
      ¡Es tu turno! Toca una subcategoría libre para elegirla.
    </p>
    <p v-else-if="me && nextQueen" class="muted" role="status">
      <template v-if="waitingBefore.length === 1">
        Solo falta {{ nextQueen.name }} antes que tú.
      </template>
      <template v-else>
        Faltan {{ waitingBefore.length }} reinas antes que tú. Ahora elige {{ nextQueen.name }}.
      </template>
    </p>
    <p v-else-if="nextQueen" class="muted" role="status">
      Turno de {{ nextQueen.name }}.
    </p>
    <p v-else class="muted" role="status">
      Todas las reinas han elegido.
    </p>

    <!-- Once I have mine, the list folds away -->
    <component :is="mySubcategory ? 'details' : 'div'" class="subcats__all">
      <summary v-if="mySubcategory">
        Ver todas las subcategorías
      </summary>
      <ul class="subcats__list">
        <li v-for="subcategory in subcategories" :key="subcategory.id">
          <!-- Taken: who has it -->
          <div v-if="queenOf(subcategory.id)" class="subcats__item subcats__item--taken">
            <span class="subcats__name">{{ subcategory.name }}</span>
            <span class="subcats__queen">
              <span class="avatar subcats__avatar">
                <img v-if="queenOf(subcategory.id)!.avatarUrl" :src="queenOf(subcategory.id)!.avatarUrl!" alt="" class="avatar__img">
                <span v-else class="avatar__initial" aria-hidden="true">{{ initial(queenOf(subcategory.id)!.name) }}</span>
              </span>
              {{ queenOf(subcategory.id)!.name }}
            </span>
          </div>
          <!-- My turn: the whole row is the button -->
          <template v-else-if="myTurn">
            <button
              type="button"
              class="subcats__item subcats__item--pick"
              :class="{ 'subcats__item--selected': selected?.id === subcategory.id }"
              @click="selected = subcategory"
            >
              <span class="subcats__name">{{ subcategory.name }}</span>
              <span class="subcats__cta" aria-hidden="true">Elegir</span>
            </button>
            <!-- Confirmation right under the tapped row (modals are full screen on phones) -->
            <div v-if="selected?.id === subcategory.id" class="subcats__confirm" role="alertdialog" aria-labelledby="subcats-confirm-text">
              <p id="subcats-confirm-text">
                ¿Elegir <strong>{{ subcategory.name }}</strong>? No podrás cambiarla después.
              </p>
              <div class="form-actions">
                <button type="button" class="btn btn--ghost" :disabled="picking" @click="selected = null">
                  Cancelar
                </button>
                <button type="button" class="btn btn--primary" :disabled="picking" @click="confirmPick">
                  {{ picking ? 'Eligiendo…' : 'Confirmar' }}
                </button>
              </div>
            </div>
          </template>
          <div v-else class="subcats__item">
            <span class="subcats__name">{{ subcategory.name }}</span>
            <span class="muted">Libre</span>
          </div>
        </li>
      </ul>
    </component>

    <details v-if="queens.length" class="subcats__order">
      <summary>Orden de elección</summary>
      <ol>
        <li v-for="queen in queens" :key="queen.id" :class="{ 'subcats__current': nextQueen?.id === queen.id }">
          {{ queen.name }}
          <span v-if="queen.subcategoryId" class="muted"> · ya ha elegido</span>
          <span v-else-if="nextQueen?.id === queen.id" class="muted"> · elige ahora</span>
        </li>
      </ol>
    </details>

    <p v-if="pickError" class="form-error" role="alert">
      {{ pickError }}
    </p>
    <p v-if="loadError && !loading" class="form-error" role="alert">
      {{ loadError }}
    </p>

  </section>
</template>

<style scoped lang="scss">
.subcats {
  width: 100%;
  max-width: 40rem;
  // The page header is pinned on phones: leave room when jumping here from the shortcut
  scroll-margin-top: 5rem;
}

.subcats__title {
  font-size: 1.125rem;
  color: var(--color-title);
}

.subcats__status {
  margin: 0;

  &--turn {
    font-weight: 700;
    color: var(--color-kicker);
  }
}

.subcats__all > summary {
  margin-bottom: var(--space-2);
  cursor: pointer;
}

.subcats__list {
  display: grid;
  gap: var(--space-2);
  padding: 0;
  margin: 0;
  list-style: none;
}

.subcats__item {
  display: flex;
  gap: var(--space-3);
  align-items: center;
  justify-content: space-between;
  width: 100%;
  min-height: 3rem;
  padding: var(--space-3);
  font: inherit;
  color: inherit;
  text-align: left;
  background: none;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);

  &--taken {
    opacity: 0.8;
  }

  &--pick {
    cursor: pointer;
    background-color: var(--color-surface);
    transition: border-color 0.15s, box-shadow 0.15s;

    &:hover,
    &:focus-visible,
    &.subcats__item--selected {
      border-color: var(--color-primary);
      box-shadow: var(--shadow-card);
    }
  }
}

.subcats__name {
  min-width: 0;
  overflow-wrap: anywhere;
}

.subcats__cta {
  flex-shrink: 0;
  padding: var(--space-1) var(--space-4);
  font-weight: 700;
  color: var(--color-on-accent);
  background-color: var(--color-primary);
  border-radius: var(--radius-pill);
}

.subcats__queen {
  display: inline-flex;
  flex-shrink: 0;
  gap: var(--space-2);
  align-items: center;
  font-size: 0.875rem;
  font-weight: 700;
  color: var(--color-kicker);
}

.subcats__avatar {
  width: 1.75rem;
  height: 1.75rem;

  .avatar__initial {
    font-size: 0.75rem;
  }
}

.subcats__order {
  ol {
    padding-left: var(--space-5);
    margin: var(--space-2) 0 0;
  }
}

.subcats__current {
  font-weight: 700;
}

.subcats__confirm {
  display: grid;
  gap: var(--space-3);
  padding: var(--space-4);
  margin-top: var(--space-2);
  background-color: var(--color-surface);
  border: 2px solid var(--color-primary);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-raised);

  p {
    margin: 0;
    overflow-wrap: anywhere;
  }
}
</style>
