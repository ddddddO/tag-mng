import Vue from 'vue'
import Router from 'vue-router'
import Home from './views/Home.vue'

Vue.use(Router)

export default new Router({
  mode: 'history',
  base: process.env.BASE_URL,
  routes: [
    {
      path: '/',
      name: 'home',
      component: Home
    },
    {
      path: '/about',
      name: 'about',
      // route level code-splitting
      // this generates a separate chunk (about.[hash].js) for this route
      // which is lazy-loaded when the route is visited.
      component: () => import(/* webpackChunkName: "about" */ './views/About.vue')
    },
    {
      path: '/memos',
      name: 'memos',
      component: () => import('./views/Memos.vue')
    },
    {
      path: '/memos/:tag_id',
      name: 'memos',
      component: () => import('./views/Memos.vue')
    },
    {
      path: '/memodetail/:memo_id',
      name: 'memo-detail',
      component: () => import('./views/MemoDetail.vue')
    },
    {
      path: '/new_memo',
      name: 'new-memo',
      component: () => import('./views/NewMemo.vue')
    },
    {
      path: '/tags',
      name: 'tags',
      component: () => import('./views/Tags.vue')
    },
    {
      path: '/tagdetail/:tag_id',
      name: 'tag-detail',
      component: () => import('./views/TagDetail.vue')
    },
    {
      path: '/new_tag',
      name: 'new-tag',
      component: () => import('./views/NewTag.vue')
    }
  ]
})
