# Changing a category in your instance of Link-Dane

There is a total of three files that you will need to edit in your Link-Dane project.

1. The first thing you will need to edit is the categories file, found at /shared/js/lib/categories.js
It shows you a list of categories in the following format:   `{ icon: 'desktop', key: 'technology', title: 'Technology' }`

  First, edit the values for key and title; i.e. change lowercase 'technology' to a lowercase, space-free version of your new category name. For example, if I want to swap Technology for School Services, I would change this key to the following: 'schoolServices'

  Then change the title to the name of your new category. For example at this point I could have something like:

  `{ icon: 'desktop', key: 'schoolServices', title: 'School Services' }`

  or

  `{ icon: 'desktop', key: 'legal', title: 'Legal' }`

2. Next, find the test for this at `/test/acceptance/tests.js`
After the word 'expected' you will see an array of categories. Change the name of the one that you want to replace with your new category.

3. Find the edit template at `/admin/js/templates/edit.hbs`
Search for the html element: `<select name="categories" id="categories" class="span2">`. Find the option for the category you are replacing, and fill it in with your new category key and title from step 1. For example, I might change `<option value="technology">Technology</option>` into this: `<option value="legal">Legal</option>`

At this point your instance of Link-Dane should show your new category name everywhere. You can also choose the icon by [following this guide](https://github.com/zendesk/link-dane/blob/master/docs/ICONS.md).
